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
