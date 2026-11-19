SET search_path TO uber;

CREATE TABLE trips_partitioned (
    LIKE trips INCLUDING ALL
) PARTITION BY RANGE (requested_at);

CREATE TABLE trips_y2025_h1 PARTITION OF trips_partitioned
    FOR VALUES FROM ('2025-01-01') TO ('2025-07-01');

CREATE TABLE trips_y2025_h2 PARTITION OF trips_partitioned
    FOR VALUES FROM ('2025-07-01') TO ('2026-01-01');

CREATE TABLE trips_y2026_h1 PARTITION OF trips_partitioned
    FOR VALUES FROM ('2026-01-01') TO ('2026-07-01');

CREATE TABLE trips_y2026_h2 PARTITION OF trips_partitioned
    FOR VALUES FROM ('2026-07-01') TO ('2027-01-01');

CREATE TABLE IF NOT EXISTS trips_default PARTITION OF trips_partitioned DEFAULT;

CREATE INDEX IF NOT EXISTS idx_trips_part_rider ON trips_partitioned (rider_id, requested_at DESC);
CREATE INDEX IF NOT EXISTS idx_trips_part_city_req ON trips_partitioned (city_id, requested_at);

INSERT INTO trips_partitioned
SELECT * FROM trips
ON CONFLICT DO NOTHING;

EXPLAIN (COSTS OFF)
SELECT trip_id, status, requested_at
FROM trips_partitioned
WHERE requested_at >= '2026-05-10' AND requested_at < '2026-05-11';
