SET search_path TO uber;
BEGIN;

-- @R09
SELECT r.rider_id, r.full_name, r.email
FROM riders r
WHERE r.home_city_id = 1
  AND NOT EXISTS (SELECT 1 FROM trips t WHERE t.rider_id = r.rider_id AND t.requested_at >= '2026-04-01');

-- @R10
SELECT d.driver_id, d.full_name, d.city_id
FROM drivers d
WHERE d.status = 'ACTIVE'
  AND NOT EXISTS (SELECT 1 FROM trips t WHERE t.driver_id = d.driver_id AND t.requested_at >= '2026-06-25');

-- @END
ROLLBACK;
