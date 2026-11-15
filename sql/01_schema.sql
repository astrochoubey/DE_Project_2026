CREATE SCHEMA IF NOT EXISTS uber;
SET search_path TO uber;

DROP TABLE IF EXISTS ratings CASCADE;
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS trips CASCADE;
DROP TABLE IF EXISTS vehicles CASCADE;
DROP TABLE IF EXISTS drivers CASCADE;
DROP TABLE IF EXISTS riders CASCADE;
DROP TABLE IF EXISTS promo_codes CASCADE;
DROP TABLE IF EXISTS cities CASCADE;

CREATE TABLE cities (
    city_id         INT PRIMARY KEY,
    city_name       VARCHAR(50) NOT NULL UNIQUE,
    state           VARCHAR(50) NOT NULL,
    base_fare       NUMERIC(6,2) NOT NULL,
    per_km_rate     NUMERIC(6,2) NOT NULL,
    per_min_rate    NUMERIC(6,2) NOT NULL,
    launched_on     DATE NOT NULL,
    CONSTRAINT chk_cities_base_fare CHECK (base_fare >= 0),
    CONSTRAINT chk_cities_km_rate CHECK (per_km_rate >= 0),
    CONSTRAINT chk_cities_min_rate CHECK (per_min_rate >= 0)
);

CREATE TABLE promo_codes (
    promo_code      VARCHAR(20) PRIMARY KEY,
    discount_pct    INT NOT NULL,
    max_discount    NUMERIC(6,2) NOT NULL,
    valid_from      DATE NOT NULL,
    valid_to        DATE NOT NULL,
    is_active       BOOLEAN NOT NULL DEFAULT true,
    CONSTRAINT chk_promo_discount_pct CHECK (discount_pct > 0 AND discount_pct <= 100),
    CONSTRAINT chk_promo_max_discount CHECK (max_discount > 0),
    CONSTRAINT chk_promo_validity_dates CHECK (valid_to >= valid_from)
);

CREATE TABLE riders (
    rider_id        INT PRIMARY KEY,
    full_name       VARCHAR(100) NOT NULL,
    email           VARCHAR(150) NOT NULL UNIQUE,
    phone           VARCHAR(15) NOT NULL UNIQUE,
    home_city_id    INT NOT NULL REFERENCES cities(city_id) ON DELETE RESTRICT,
    signup_date     DATE NOT NULL,
    rider_rating    NUMERIC(2,1),
    is_active       BOOLEAN NOT NULL DEFAULT true,
    CONSTRAINT chk_riders_phone CHECK (phone ~ '^[0-9]{10}$'),
    CONSTRAINT chk_riders_rating CHECK (rider_rating IS NULL OR (rider_rating >= 1.0 AND rider_rating <= 5.0))
);

CREATE TABLE drivers (
    driver_id       INT PRIMARY KEY,
    full_name       VARCHAR(100) NOT NULL,
    phone           VARCHAR(15) NOT NULL UNIQUE,
    license_no      VARCHAR(30) NOT NULL UNIQUE,
    city_id         INT NOT NULL REFERENCES cities(city_id) ON DELETE RESTRICT,
    joined_on       DATE NOT NULL,
    driver_rating   NUMERIC(2,1) NOT NULL,
    status          VARCHAR(20) NOT NULL,
    CONSTRAINT chk_drivers_phone CHECK (phone ~ '^[0-9]{10}$'),
    CONSTRAINT chk_drivers_rating CHECK (driver_rating >= 1.0 AND driver_rating <= 5.0),
    CONSTRAINT chk_drivers_status CHECK (status IN ('ACTIVE', 'INACTIVE', 'SUSPENDED'))
);

CREATE TABLE vehicles (
    vehicle_id        INT PRIMARY KEY,
    driver_id         INT NOT NULL REFERENCES drivers(driver_id) ON DELETE RESTRICT,
    registration_no   VARCHAR(20) NOT NULL UNIQUE,
    make              VARCHAR(50) NOT NULL,
    model             VARCHAR(50) NOT NULL,
    manufacture_year  INT NOT NULL,
    vehicle_type      VARCHAR(20) NOT NULL,
    seat_capacity     INT NOT NULL,
    CONSTRAINT chk_vehicles_year CHECK (manufacture_year BETWEEN 2000 AND 2030),
    CONSTRAINT chk_vehicles_type CHECK (vehicle_type IN ('AUTO', 'BIKE', 'MINI', 'SEDAN', 'SUV')),
    CONSTRAINT chk_vehicles_capacity CHECK (seat_capacity > 0),
    CONSTRAINT chk_vehicles_type_seat_match CHECK (
        (vehicle_type = 'BIKE' AND seat_capacity = 1) OR
        (vehicle_type = 'AUTO' AND seat_capacity = 3) OR
        (vehicle_type = 'MINI' AND seat_capacity = 4) OR
        (vehicle_type = 'SEDAN' AND seat_capacity = 4) OR
        (vehicle_type = 'SUV' AND seat_capacity IN (6, 7))
    )
);

CREATE TABLE trips (
    trip_id           BIGINT PRIMARY KEY,
    rider_id          INT NOT NULL REFERENCES riders(rider_id) ON DELETE RESTRICT,
    driver_id         INT REFERENCES drivers(driver_id) ON DELETE RESTRICT,
    vehicle_id        INT REFERENCES vehicles(vehicle_id) ON DELETE RESTRICT,
    city_id           INT NOT NULL REFERENCES cities(city_id) ON DELETE RESTRICT,
    promo_code        VARCHAR(20) REFERENCES promo_codes(promo_code) ON DELETE SET NULL,
    requested_at      TIMESTAMPTZ NOT NULL,
    pickup_at         TIMESTAMPTZ,
    dropoff_at        TIMESTAMPTZ,
    pickup_lat        NUMERIC(9,6) NOT NULL,
    pickup_lng        NUMERIC(9,6) NOT NULL,
    drop_lat          NUMERIC(9,6) NOT NULL,
    drop_lng          NUMERIC(9,6) NOT NULL,
    distance_km       NUMERIC(6,2),
    duration_min      INT,
    surge_multiplier  NUMERIC(3,2) NOT NULL DEFAULT 1.00,
    fare_amount       NUMERIC(8,2),
    status            VARCHAR(30) NOT NULL,
    CONSTRAINT chk_trips_coords_pickup CHECK (
        pickup_lat BETWEEN -90.0 AND 90.0 AND pickup_lng BETWEEN -180.0 AND 180.0
    ),
    CONSTRAINT chk_trips_coords_drop CHECK (
        drop_lat BETWEEN -90.0 AND 90.0 AND drop_lng BETWEEN -180.0 AND 180.0
    ),
    CONSTRAINT chk_trips_surge CHECK (surge_multiplier >= 1.00),
    CONSTRAINT chk_trips_distance CHECK (distance_km IS NULL OR distance_km >= 0),
    CONSTRAINT chk_trips_duration CHECK (duration_min IS NULL OR duration_min >= 0),
    CONSTRAINT chk_trips_fare CHECK (fare_amount IS NULL OR fare_amount >= 0),
    CONSTRAINT chk_trips_status CHECK (status IN (
        'REQUESTED', 'ACCEPTED', 'ONGOING', 'COMPLETED',
        'CANCELLED_BY_RIDER', 'CANCELLED_BY_DRIVER'
    )),
    CONSTRAINT chk_trips_timeline_pickup CHECK (pickup_at IS NULL OR pickup_at >= requested_at),
    CONSTRAINT chk_trips_timeline_dropoff CHECK (dropoff_at IS NULL OR pickup_at IS NULL OR dropoff_at >= pickup_at),
    CONSTRAINT chk_trips_completed_integrity CHECK (
        status != 'COMPLETED' OR (
            driver_id IS NOT NULL AND
            vehicle_id IS NOT NULL AND
            pickup_at IS NOT NULL AND
            dropoff_at IS NOT NULL AND
            distance_km IS NOT NULL AND
            duration_min IS NOT NULL AND
            fare_amount IS NOT NULL
        )
    )
);

CREATE TABLE payments (
    payment_id      INT PRIMARY KEY,
    trip_id         BIGINT NOT NULL UNIQUE REFERENCES trips(trip_id) ON DELETE CASCADE,
    amount          NUMERIC(8,2) NOT NULL,
    method          VARCHAR(20) NOT NULL,
    payment_status  VARCHAR(20) NOT NULL,
    paid_at         TIMESTAMPTZ NOT NULL,
    CONSTRAINT chk_payments_amount CHECK (amount >= 0),
    CONSTRAINT chk_payments_method CHECK (method IN ('UPI', 'CASH', 'CARD', 'WALLET')),
    CONSTRAINT chk_payments_status CHECK (payment_status IN ('SUCCESS', 'FAILED', 'REFUNDED'))
);

CREATE TABLE ratings (
    trip_id         BIGINT NOT NULL REFERENCES trips(trip_id) ON DELETE CASCADE,
    rated_by        VARCHAR(10) NOT NULL,
    stars           SMALLINT NOT NULL,
    comment         VARCHAR(255),
    created_at      TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (trip_id, rated_by),
    CONSTRAINT chk_ratings_rated_by CHECK (rated_by IN ('RIDER', 'DRIVER')),
    CONSTRAINT chk_ratings_stars CHECK (stars BETWEEN 1 AND 5)
);
