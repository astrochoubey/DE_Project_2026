\set ON_ERROR_STOP on
SET search_path TO uber;

-- 1. Table Row Counts & Population Verification
SELECT
    expected.table_name,
    actual.actual_rows,
    expected.expected_rows,
    CASE WHEN actual.actual_rows = expected.expected_rows THEN 'PASS' ELSE 'FAIL' END AS status
FROM (
    SELECT 'cities' AS table_name, count(*) AS actual_rows FROM cities
    UNION ALL SELECT 'promo_codes', count(*) FROM promo_codes
    UNION ALL SELECT 'riders', count(*) FROM riders
    UNION ALL SELECT 'drivers', count(*) FROM drivers
    UNION ALL SELECT 'vehicles', count(*) FROM vehicles
    UNION ALL SELECT 'trips', count(*) FROM trips
    UNION ALL SELECT 'payments', count(*) FROM payments
    UNION ALL SELECT 'ratings', count(*) FROM ratings
) actual
JOIN (
    VALUES
        ('cities', 10),
        ('promo_codes', 40),
        ('riders', 30000),
        ('drivers', 3000),
        ('vehicles', 3300),
        ('trips', 300000),
        ('payments', 245839),
        ('ratings', 307214)
) AS expected(table_name, expected_rows) ON actual.table_name = expected.table_name
ORDER BY expected.table_name;

-- 2. Relational Integrity & Business Invariants
SELECT
    (SELECT count(*) FROM payments p LEFT JOIN trips t ON p.trip_id = t.trip_id WHERE t.trip_id IS NULL OR t.status != 'COMPLETED') AS orphan_or_uncompleted_payments,
    (SELECT count(*) FROM trips t JOIN vehicles v ON t.vehicle_id = v.vehicle_id WHERE t.driver_id IS NOT NULL AND t.vehicle_id IS NOT NULL AND v.driver_id != t.driver_id) AS vehicle_driver_mismatches,
    (SELECT count(*) FROM trips t JOIN payments p ON t.trip_id = p.trip_id WHERE t.fare_amount IS NOT NULL AND abs(p.amount - t.fare_amount) > 0.001) AS fare_payment_mismatches,
    (SELECT count(*) FROM trips t LEFT JOIN payments p ON t.trip_id = p.trip_id WHERE (t.pickup_at IS NOT NULL AND t.pickup_at < t.requested_at) OR (t.dropoff_at IS NOT NULL AND t.pickup_at IS NOT NULL AND t.dropoff_at < t.pickup_at) OR (p.paid_at IS NOT NULL AND t.dropoff_at IS NOT NULL AND p.paid_at < t.dropoff_at)) AS timeline_violations;

-- 3. Geographic Boundaries & Telemetry Integrity
SELECT
    count(*) FILTER (WHERE pickup_lat < 8.0 OR pickup_lat > 37.0 OR pickup_lng < 68.0 OR pickup_lng > 97.0) AS out_of_bounds_pickups,
    count(*) FILTER (WHERE drop_lat < 8.0 OR drop_lat > 37.0 OR drop_lng < 68.0 OR drop_lng > 97.0) AS out_of_bounds_drops,
    count(*) FILTER (WHERE status = 'COMPLETED' AND (fare_amount IS NULL OR distance_km IS NULL OR duration_min IS NULL)) AS incomplete_completed_trips
FROM trips;
