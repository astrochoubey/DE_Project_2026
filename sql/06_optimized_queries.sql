-- =====================================================================
-- Phase 4 – Optimized Query Rewrites
-- File: sql/06_optimized_queries.sql
--
-- PURPOSE
--   Rewritten versions of selected workload queries from
--   queries/workload_30.sql that perform poorly at baseline.
--   The original file is NOT modified (project rules).
--
-- QUERIES REWRITTEN
--   R18 – correlated subquery → aggregate JOIN  (15 734 ms → target <50 ms)
--   R09 – NOT IN (subquery)  → NOT EXISTS        (safer with NULLs, faster)
--   R10 – NOT IN (subquery)  → NOT EXISTS        (same reasoning as R09)
--   R20 – requested_at::date cast → range filter (allows index on requested_at)
--   R16 – OFFSET deep pagination → deferred join via primary key
--   R07 – pre-join filter & aggregation push-down
--
-- HOW TO TEST
--   psql -d capstone -f sql/06_optimized_queries.sql
--
-- NOTE: Every statement below is wrapped in BEGIN … ROLLBACK so that
--   write queries leave the database unchanged, identical to the original
--   workload file behaviour.
-- =====================================================================
SET search_path TO uber;
BEGIN;

-- @R18
-- CRM: last trip date of every rider in Pune
-- ORIGINAL: correlated scalar subquery – fired once per Pune rider,
--   causing a full Seq Scan of trips for each rider → 15 734 ms.
-- FIX: pre-aggregate with MAX() in a lateral/derived table, then join.
--   With idx_trips_rider_requested the planner resolves MAX in O(1)
--   per rider using an Index Scan instead of a Seq Scan.
SELECT r.rider_id, r.full_name, t_agg.last_trip_at
FROM riders r
LEFT JOIN (
    SELECT rider_id, MAX(requested_at) AS last_trip_at
    FROM trips
    GROUP BY rider_id
) t_agg ON t_agg.rider_id = r.rider_id
WHERE r.home_city_id = 6
ORDER BY t_agg.last_trip_at DESC NULLS LAST;

-- @R09
-- Marketing: Bengaluru riders with no trip since 1 April 2026
-- ORIGINAL: NOT IN (subquery) – unsafe when subquery returns a NULL
--   (NOT IN returns NULL/unknown for every row if any trip has rider_id NULL).
--   Also slower on large sets.
-- FIX: NOT EXISTS with a correlated subquery is NULL-safe and lets the
--   planner use idx_trips_rider_requested to find the matching row fast.
SELECT r.rider_id, r.full_name, r.email
FROM riders r
WHERE r.home_city_id = 1
  AND NOT EXISTS (
      SELECT 1
      FROM trips t
      WHERE t.rider_id = r.rider_id
        AND t.requested_at >= '2026-04-01'
  );

-- @R10
-- Driver ops: active drivers with no trip since 25 June 2026
-- ORIGINAL: NOT IN (subquery) – same NULL-safety issue as R09.
-- FIX: NOT EXISTS, same reasoning.
SELECT d.driver_id, d.full_name, d.city_id
FROM drivers d
WHERE d.status = 'ACTIVE'
  AND NOT EXISTS (
      SELECT 1
      FROM trips t
      WHERE t.driver_id = d.driver_id
        AND t.requested_at >= '2026-06-25'
  );

-- @R20
-- Finance: daily revenue and running total for May 2026
-- ORIGINAL: requested_at::date in both SELECT and WHERE – the cast in
--   WHERE prevents the planner from using a range index on requested_at.
-- FIX: replace cast-based filter with an explicit timestamp range so the
--   planner can use idx_trips_driver_status_date or any btree index on
--   requested_at.
SELECT day, revenue, SUM(revenue) OVER (ORDER BY day) AS running_total
FROM (
    SELECT requested_at::date AS day, SUM(fare_amount) AS revenue
    FROM trips
    WHERE status = 'COMPLETED'
      AND requested_at >= '2026-05-01'
      AND requested_at <  '2026-06-01'
    GROUP BY 1
) daily
ORDER BY day;

-- @R16
-- Admin panel: "All trips" table, page 8,001 (25 rows per page)
-- ORIGINAL: OFFSET 200000 LIMIT 25 on SELECT * retrieves all columns
--   for 200,025 tuples before discarding 200,000.
-- FIX: Deferred join. The subquery operates as an Index Only Scan on trips_pkey
--   to resolve the 25 target IDs, then joins back to fetch full attributes.
SELECT t.trip_id, t.rider_id, t.driver_id, t.city_id, t.status, t.fare_amount, t.requested_at
FROM (
    SELECT trip_id
    FROM trips
    ORDER BY trip_id DESC
    OFFSET 200000
    LIMIT 25
) p
JOIN trips t ON t.trip_id = p.trip_id
ORDER BY t.trip_id DESC;

-- @R07
-- Top 10 earning drivers in Mumbai, Q1 2026
-- ORIGINAL: Joins drivers, trips, and cities before aggregation, creating
--   large intermediate join cardinality.
-- FIX: Push-down aggregation: aggregate trips by driver_id first within
--   Mumbai's city_id (2) and Q1 2026, then join the top candidates with drivers.
SELECT d.driver_id, d.full_name, t_agg.trips, t_agg.earnings
FROM (
    SELECT driver_id, count(*) AS trips, sum(fare_amount) AS earnings
    FROM trips
    WHERE city_id = 2
      AND status = 'COMPLETED'
      AND requested_at >= '2026-01-01' AND requested_at < '2026-04-01'
    GROUP BY driver_id
) t_agg
JOIN drivers d ON d.driver_id = t_agg.driver_id
ORDER BY t_agg.earnings DESC
LIMIT 10;

-- @END
ROLLBACK;
