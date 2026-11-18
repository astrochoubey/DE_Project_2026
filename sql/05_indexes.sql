-- =====================================================================
-- Phase 4 – Index Optimization
-- File: sql/05_indexes.sql
--
-- PURPOSE
--   Add targeted indexes identified from EXPLAIN ANALYZE output in the
--   Phase 3 baseline benchmark.  Every index below is chosen to convert
--   a Seq Scan that showed up in a slow query into an Index Scan.
--
-- HOW TO APPLY
--   psql -d capstone -f sql/05_indexes.sql
--
-- AFTER APPLYING
--   Run ANALYZE so the planner uses fresh statistics:
--   psql -d capstone -c "ANALYZE;"
--   Then re-benchmark: ./benchmarks/run_benchmark.sh capstone optimized 3
-- =====================================================================
SET search_path TO uber;

-- -------------------------------------------------------------------
-- R01 "Your trips" – rider_id filter + ORDER BY requested_at DESC
-- R02 Driver earnings – driver_id + status + date range filter
-- Covering both: a composite index on (rider_id, requested_at DESC)
-- and one on (driver_id, status, requested_at).
-- -------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_trips_rider_requested
    ON uber.trips (rider_id, requested_at DESC);

CREATE INDEX IF NOT EXISTS idx_trips_driver_status_date
    ON uber.trips (driver_id, status, requested_at);

-- -------------------------------------------------------------------
-- R03 Login – LOWER(email) lookup.  Functional (expression) index so
-- the planner can use it even when the caller writes LOWER(email).
-- -------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_riders_email_lower
    ON uber.riders (LOWER(email));

-- -------------------------------------------------------------------
-- R05 Live dispatch – status IN ('REQUESTED','ACCEPTED','ONGOING')
-- A partial index on only those rows keeps it small and selective.
-- -------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_trips_status_active
    ON uber.trips (status, requested_at)
    WHERE status IN ('REQUESTED', 'ACCEPTED', 'ONGOING');

-- -------------------------------------------------------------------
-- R08 Finance – payments filtered by payment_status + year(paid_at).
-- A composite index lets the planner skip the full table scan.
-- -------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_payments_status_paid
    ON uber.payments (payment_status, paid_at);

-- -------------------------------------------------------------------
-- R18 CRM (CRITICAL – 15 734 ms baseline)
-- The correlated subquery "SELECT max(requested_at) FROM trips
-- WHERE rider_id = r.rider_id" fires once per Pune rider.
-- An index on (rider_id, requested_at DESC) lets each sub-execution
-- resolve with an Index Scan of 1 row instead of a full Seq Scan.
-- The optimized rewrite in sql/06_optimized_queries.sql eliminates
-- the correlated subquery entirely; this index also helps the rewrite.
-- -------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_trips_rider_requested_cover
    ON uber.trips (rider_id, requested_at DESC);
-- Note: idx_trips_rider_requested (created above for R01) is identical
-- in key columns; PostgreSQL will reuse it.  The explicit name here
-- documents intent; IF NOT EXISTS prevents a duplicate.

-- -------------------------------------------------------------------
-- R23 Growth – count(DISTINCT rider_id) per city per month.
-- A composite index on (city_id, requested_at, rider_id) lets the
-- planner use an Index Only Scan for this aggregation.
-- -------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_trips_city_month_rider
    ON uber.trips (city_id, requested_at, rider_id);

-- -------------------------------------------------------------------
-- R11 Quality – ratings join on trip_id, filtered by rated_by.
-- An index on (rated_by, trip_id) makes the join much cheaper.
-- -------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_ratings_rated_by_trip
    ON uber.ratings (rated_by, trip_id);
