SET search_path TO uber;

SELECT 'orphan_payments' AS check_name, count(*) AS violations
FROM payments p
LEFT JOIN trips t ON p.trip_id = t.trip_id
WHERE t.trip_id IS NULL;

SELECT 'vehicle_driver_mismatch' AS check_name, count(*) AS violations
FROM trips t
JOIN vehicles v ON t.vehicle_id = v.vehicle_id
WHERE t.driver_id IS NOT NULL AND v.driver_id != t.driver_id;

SELECT 'completed_without_payment' AS check_name, count(*) AS violations
FROM trips t
LEFT JOIN payments p ON t.trip_id = p.trip_id
WHERE t.status = 'COMPLETED' AND p.payment_id IS NULL;
