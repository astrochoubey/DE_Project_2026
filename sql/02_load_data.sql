SET search_path TO uber;

\copy cities FROM 'seed_data/cities.csv' WITH (FORMAT csv, HEADER true);
\copy promo_codes FROM 'seed_data/promo_codes.csv' WITH (FORMAT csv, HEADER true);
\copy riders FROM 'seed_data/riders.csv' WITH (FORMAT csv, HEADER true);
\copy drivers FROM 'seed_data/drivers.csv' WITH (FORMAT csv, HEADER true);
\copy vehicles FROM 'seed_data/vehicles.csv' WITH (FORMAT csv, HEADER true);
\copy trips FROM 'seed_data/trips.csv' WITH (FORMAT csv, HEADER true);
\copy payments FROM 'seed_data/payments.csv' WITH (FORMAT csv, HEADER true);
\copy ratings FROM 'seed_data/ratings.csv' WITH (FORMAT csv, HEADER true);

ANALYZE;
