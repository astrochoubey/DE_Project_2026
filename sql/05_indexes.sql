SET search_path TO uber;

CREATE INDEX idx_trips_rider_requested ON trips (rider_id, requested_at DESC);

CREATE INDEX idx_trips_driver_status_requested ON trips (driver_id, status, requested_at);

CREATE INDEX idx_riders_lower_email ON riders (LOWER(email));

CREATE INDEX idx_trips_status_requested ON trips (status, requested_at)
    WHERE status IN ('REQUESTED', 'ACCEPTED', 'ONGOING');

CREATE INDEX idx_payments_status_paid ON payments (payment_status, paid_at);

CREATE INDEX idx_trips_completed_fare ON trips (status, fare_amount)
    WHERE status = 'COMPLETED';

CREATE INDEX idx_vehicles_regno ON vehicles (registration_no);

CREATE INDEX idx_riders_city ON riders (home_city_id);

ANALYZE;
