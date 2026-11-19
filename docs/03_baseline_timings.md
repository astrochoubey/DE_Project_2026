# Phase 3: Baseline Query Timings

**Course:** Database Management Systems (B.Tech 2nd Year)
**Team:** T0141 Brutus · Section C
**Database Engine:** PostgreSQL 18 (Homebrew) · Apple MacBook
**Measurement Method:** `EXPLAIN (ANALYZE, BUFFERS)` via `./benchmarks/run_benchmark.sh capstone baseline 3`
**Runs per query:** 3 · Write queries run inside `BEGIN … ROLLBACK` (data unchanged)
**Raw plans committed:** `benchmarks/results/baseline/R01.txt … W05.txt`

---

## Timing Table

| SQL Query | Type | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) |
|---|---|---:|---:|---:|---:|
| R01: Rider's last 20 trips | READ | 12.045 | 9.451 | 7.345 | **9.614** |
| R02: Driver March 2026 earnings | READ | 10.039 | 8.760 | 8.714 | **9.171** |
| R03: Login by email (case-insensitive) | READ | 7.800 | 6.325 | 6.345 | **6.823** |
| R04: Bengaluru trips on 10 May 2026 | READ | 6.523 | 6.853 | 6.777 | **6.718** |
| R05: Oldest in-progress trips (dispatch) | READ | 11.540 | 15.053 | 15.771 | **14.121** |
| R06: Completed trips per city, June 2026 | READ | 16.842 | 11.264 | 10.975 | **13.027** |
| R07: Top 10 earning drivers in Mumbai, Q1 2026 | READ | 13.983 | 11.401 | 10.794 | **12.059** |
| R08: Revenue per payment method per month, 2026 | READ | 28.109 | 28.752 | 28.148 | **28.336** |
| R09: Bengaluru riders inactive since April 2026 | READ | 17.040 | 16.876 | 16.691 | **16.869** |
| R10: Active drivers with no trip since 25 June 2026 | READ | 11.517 | 11.354 | 11.239 | **11.370** |
| R11: 20 lowest-rated drivers | READ | 30.687 | 29.987 | 30.221 | **30.298** |
| R12: Average surge by hour in Delhi | READ | 30.116 | 30.175 | 29.616 | **29.969** |
| R13: Search riders by surname | READ | 8.858 | 8.987 | 8.835 | **8.893** |
| R14: Vehicle + driver by registration number | READ | 0.031 | 0.030 | 0.030 | **0.030** |
| R15: Trip receipt | READ | 0.069 | 0.066 | 0.067 | **0.067** |
| R16: Admin panel page 8,001 | READ | 22.626 | 23.362 | 21.207 | **22.398** |
| R17: Cancellation rate per city | READ | 24.838 | 24.904 | 22.987 | **24.243** |
| R18: Last trip date of every Pune rider | READ | 15887.210 | 15721.078 | 15596.692 | **15734.993** |
| R19: Top 3 drivers per city, May 2026 | READ | 11.327 | 10.562 | 10.258 | **10.716** |
| R20: Daily revenue + running total, May 2026 | READ | 12.738 | 13.190 | 13.058 | **12.995** |
| R21: Promo code usage | READ | 18.580 | 18.489 | 18.624 | **18.564** |
| R22: Failed payments, last 7 days | READ | 13.895 | 6.273 | 6.274 | **8.814** |
| R23: Distinct active riders per city per month | READ | 50.074 | 51.782 | 50.432 | **50.763** |
| R24: Unusually long trips | READ | 10.820 | 10.791 | 10.824 | **10.812** |
| R25: Trips charging more than ₹100/km | READ | 16.586 | 16.840 | 16.006 | **16.477** |
| W01: Request a new trip | WRITE | 0.799 | 0.529 | 0.560 | **0.629** |
| W02: Complete the oldest ongoing trip | WRITE | 25.104 | 24.424 | 24.281 | **24.603** |
| W03: Suspend low-rated drivers | WRITE | 3.873 | 3.604 | 3.056 | **3.511** |
| W04: Bulk import of 5,000 trips | WRITE | 28.122 | 29.813 | 29.738 | **29.224** |
| W05: Purge cancelled trips from Jan 2025 | WRITE | 29.140 | 30.198 | 29.578 | **29.639** |
| **Total (sum of all 30 averages)** | | | | | **16,217.089** |

---

## Scan Type & Reason per Query

| Query | Scan Type | Why It Is Slow / Fast |
|---|---|---|
| R01 | Seq Scan on trips | No index on `rider_id` — full 300k-row scan to filter one rider. |
| R02 | Seq Scan on trips | No index on `driver_id` + `status` + date — full table scan with function `DATE()`. |
| R03 | Seq Scan on riders | `LOWER(email)` disables the B-tree index on `email`; needs a functional index. |
| R04 | Seq Scan on trips, cities | No composite index on `(city_id, requested_at)` for the date-range filter. |
| R05 | Seq Scan on trips | No partial index on the three in-progress status values (<0.1% of rows). |
| R06 | Seq Scan on trips, cities | Full scan to aggregate completed trips in a one-month window. |
| R07 | Seq Scan on trips, drivers, cities | Three-table join with no indexes on `driver_id`, `status`, or date range. |
| R08 | Seq Scan on payments | Full scan across 245k payment rows; no index on `payment_status` + `paid_at`. |
| R09 | Seq Scan on riders, trips | `NOT IN` subquery triggers full scan on both tables. |
| R10 | Seq Scan on drivers, trips | `NOT IN` subquery with no index on driver status or trip date. |
| R11 | Seq Scan on trips, ratings | Aggregation join across 307k ratings with no index on `rated_by`. |
| R12 | Seq Scan on trips, cities | Full scan to group surge by hour across all Delhi trips. |
| R13 | Seq Scan on riders | `ILIKE '%sharma%'` requires a full scan; needs a GIN trigram index. |
| R14 | Index Scan (vehicles, drivers) | `registration_no` has a UNIQUE constraint → automatic B-tree index. Fast. |
| R15 | Index Scan (5 tables) | All joins on primary/unique keys — all 5 index seeks complete in <0.1 ms. |
| R16 | Index Scan (trips PK) | PK index used but `OFFSET 200000` discards 200k tuples — deep pagination problem. |
| R17 | Seq Scan on trips, cities | Aggregation over all 300k trips with FILTER for cancellation pattern. |
| R18 | Seq Scan on riders, trips | **Worst query (15.7 s):** 30k correlated subqueries, one per Pune rider — no index on `(rider_id, requested_at)`. |
| R19 | Seq Scan on trips, drivers | Window function RANK() after full join scan; no index on `(driver_id, status, requested_at)`. |
| R20 | Seq Scan on trips | Date-cast `requested_at::date` prevents index use; aggregation over May 2026. |
| R21 | Seq Scan on trips, promo_codes | Left join across all 300k trips to match 40 promo codes. |
| R22 | Seq Scan on payments + Index | Payments scanned for `FAILED` status; then index seeks on trips and riders. |
| R23 | Seq Scan on trips | `COUNT(DISTINCT rider_id)` with date filter — full 300k scan. |
| R24 | Seq Scan on trips | Range filter on `distance_km > 43 OR duration_min > 150` with no index. |
| R25 | Seq Scan on trips | Division expression `fare_amount / NULLIF(distance_km, 0) > 100` prevents index. |
| W01 | (no scan) | Simple INSERT by PK — instant. |
| W02 | Index Scan (trips PK) | Subquery finds `min(trip_id)` with status filter, then PK update. |
| W03 | Seq Scan on drivers | Full scan of 3k drivers to find `ACTIVE` with `driver_rating < 3.5`. |
| W04 | (no scan) | Bulk INSERT via `generate_series` — no table reads needed. |
| W05 | Seq Scan on trips | Full scan to find `CANCELLED%` trips in Jan 2025 date range. |
