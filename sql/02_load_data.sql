-- =====================================================================
-- Uber Ride-Hailing Database: Seed Data Loading Script (Phase 2)
-- Course: Database Management Systems (DE Project)
-- Database: PostgreSQL 15 or newer
-- Schema: uber
--
-- Loads all 8 CSV exports into PostgreSQL in topological order
-- respecting foreign key dependency hierarchies.
--
-- Usage:
--   psql -d <database_name> -f sql/02_load_data.sql
-- =====================================================================

SET search_path TO uber;

-- 1. Base reference tables without foreign dependencies
\copy cities FROM 'seed_data/cities.csv' WITH (FORMAT csv, HEADER true);
\copy promo_codes FROM 'seed_data/promo_codes.csv' WITH (FORMAT csv, HEADER true);

-- 2. User & Driver entities referencing cities
\copy riders FROM 'seed_data/riders.csv' WITH (FORMAT csv, HEADER true);
\copy drivers FROM 'seed_data/drivers.csv' WITH (FORMAT csv, HEADER true);

-- 3. Vehicle fleet referencing drivers
\copy vehicles FROM 'seed_data/vehicles.csv' WITH (FORMAT csv, HEADER true);

-- 4. Central transactions referencing riders, drivers, vehicles, cities, promo_codes
\copy trips FROM 'seed_data/trips.csv' WITH (FORMAT csv, HEADER true);

-- 5. Dependent transaction extensions referencing trips
\copy payments FROM 'seed_data/payments.csv' WITH (FORMAT csv, HEADER true);
\copy ratings FROM 'seed_data/ratings.csv' WITH (FORMAT csv, HEADER true);

-- 6. Collect table statistics for query planner optimization
ANALYZE;
