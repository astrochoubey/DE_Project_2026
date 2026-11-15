# Phase 1: Problem Understanding & Workload Analysis

**Course:** Database Management Systems (B.Tech 2nd Year)  
**System:** Uber India Ride-Hailing Database (10 Operating Cities)  
**Database Engine:** PostgreSQL 15+  
**Deliverable:** `docs/01_problem_understanding.md`

---

## 1. Overview & Operational Context

Uber India operates multi-modal urban mobility services across 10 major metropolitan cities: **Bengaluru, Mumbai, Delhi, Hyderabad, Chennai, Pune, Kolkata, Ahmedabad, Jaipur, and Lucknow**. The platform matches riders with drivers in real time, manages dynamic pricing (surge), processes digital payments, and tracks two-sided user ratings.

The legacy database infrastructure was deployed rapidly without formal normalization, declarative constraints, or index tuning. With current seed volume at 300,000 trips and an anticipated 10–20× scale (6+ million trips), critical operational bottlenecks and data anomalies have emerged across departments.

---

## 2. Business Problem Analysis (P1 – P9)

### P1: Rider Trip History Latency
* **Stakeholder:** Rider / Rider Mobile Experience Team
* **Business Need:** High-frequency riders frequently open the "Your Trips" screen to review past rides, obtain expense invoices, or report lost items (`R01`, `R15`). Under the unindexed schema, retrieving the 20 most recent trips forces a sequential scan across the entire historical `trips` table.
* **Classification:** **Customer-Facing / Real-Time OLTP**
* **Target SLA:** **< 5 ms** (Large Dataset: < 5 ms)

### P2: Driver Earnings Dashboard Degradation
* **Stakeholder:** Driver Partners / Driver Operations & Compensation Team
* **Business Need:** Driver partners consult their daily and monthly earnings summary multiple times per shift (`R02`), as well as city leaderboard standings (`R07`, `R19`). Instant financial visibility directly impacts driver trust and platform retention. Full-table aggregation across date filters stalls the driver application.
* **Classification:** **Customer-Facing / Real-Time OLTP**
* **Target SLA:** **< 5 ms** (Aggregations: < 50 ms)

### P3: Case-Insensitive Email Authentication Failure
* **Stakeholder:** End Users (Riders & Drivers) / Identity & Access Management Team
* **Business Need:** Mobile users routinely input email addresses with arbitrary capitalization (e.g., `Karan.Verma1042@Mail.com`). A patch using `LOWER(email)` (`R03`) prevented standard B-tree index usage, degrading login authentication times and causing high connection pool latency during peak login hours.
* **Classification:** **Customer-Facing / Real-Time OLTP**
* **Target SLA:** **< 5 ms**

### P4: Live Dispatch Dashboard Refresh Lag
* **Stakeholder:** City Operations Center / Dispatch & Marketplace Health Team
* **Business Need:** City dispatch consoles must refresh every 3 seconds to display active, pending, and unfulfilled trips (`R04`, `R05`) while handling concurrent ride creation (`W01`, `W04`) and status transitions (`W02`). When each polling query takes longer than the 3-second cycle, dispatchers operate on stale data, causing delayed driver allocations.
* **Classification:** **Real-Time Operational / Low-Latency OLTP**
* **Target SLA:** **< 5 ms** (Refresh cycle target < 50 ms under concurrent load)

### P5: Monthly Finance Reports & Reconciliation Timeouts
* **Stakeholder:** Finance, Accounting & Payment Settlements Team
* **Business Need:** Month-end financial reporting computes gross booking value (GBV), platform revenue partitioned by payment gateway (UPI, Cash, Card, Wallet) (`R08`), daily running cash flows (`R20`), and failed transaction audits (`R22`). Full-table aggregations without time-partitioned or covering indexes cause transaction timeouts.
* **Classification:** **Reporting / Batch Analytics (OLAP)**
* **Target SLA:** **< 5,000 ms** (Interactive settlement audits < 250 ms)

### P6: Marketing Win-Back Campaign Target Inaccuracies
* **Stakeholder:** Growth Marketing / CRM / Driver Retention Team
* **Business Need:** Marketing runs targeted re-engagement incentives for riders and drivers inactive for over 30–60 days in specific markets (`R09`, `R10`, `R18`). Existing queries utilize inefficient and semantically hazardous anti-joins (`NOT IN (SELECT ...)`), which degrade dramatically and risk returning empty result sets when `NULL` values are present.
* **Classification:** **Reporting / Targeted Campaign Analytics**
* **Target SLA:** **< 5,000 ms**

### P7: Fraud Auditing & Trust/Safety Scan Latency
* **Stakeholder:** Trust & Safety / Risk Management / Compliance
* **Business Need:** Automated safety scans inspect trips for GPS spoofing, fare fraud, and route manipulation (e.g., trips > 43 km, durations > 150 min, or rates > ₹100/km) (`R24`, `R25`). Unindexed table sweeps consume heavy I/O buffers and lock shared database resources during live operations.
* **Classification:** **Near-Real-Time Ops & Risk Auditing**
* **Target SLA:** **< 250 ms**

### P8: Administrative Console Deep Pagination Slowness
* **Stakeholder:** Customer Support / Executive Escalations / Platform Administrators
* **Business Need:** Support agents navigating the global trips catalog (`R16`) experience severe UI hangs when browsing deep pages (e.g., Page 8,001 with `OFFSET 200000 LIMIT 25`). PostgreSQL must read and discard 200,000 tuples for every deep pagination request.
* **Classification:** **Interactive Operations / Admin Tooling**
* **Target SLA:** **< 5 ms** (Keyset/Indexed seek)

### P9: Strategic Growth Analytics & Scalability Bottlenecks
* **Stakeholder:** Executive Leadership / City General Managers / Business Intelligence
* **Business Need:** Leadership requires aggregate visibility into city-level cancellation patterns (`R17`), hourly surge distributions (`R12`), driver rating distributions (`R11`), promo code adoption (`R21`), and monthly active riders (`R23`). With volume expanding from 300,000 to 6,000,000+ trips, unindexed analytical queries will render BI dashboards unusable.
* **Classification:** **Reporting / Executive Analytics (OLAP)**
* **Target SLA:** **< 5,000 ms**

---

## 3. Workload Classification & Performance Targets Summary

| Problem ID | Problem Description | Stakeholders Affected | Query References | Workload Classification | Large Dataset SLA Target |
|:---|:---|:---|:---|:---|:---|
| **P1** | Rider "Your Trips" history latency | Riders, Rider App Team | `R01`, `R15` | Customer-Facing / Real-Time | **< 5 ms** |
| **P2** | Driver earnings summary slowness | Driver Partners, Driver Ops | `R02`, `R07`, `R19` | Customer-Facing / Real-Time | **< 5 ms** |
| **P3** | Case-insensitive login delays | All Users, Identity & Auth | `R03` | Customer-Facing / Real-Time | **< 5 ms** |
| **P4** | 3-second live dispatch refresh lag | City Ops, Dispatchers | `R04`, `R05`, `W01`, `W02` | Real-Time Operational | **< 5 ms** |
| **P5** | Month-end financial reporting timeouts | Finance, Accounting | `R08`, `R20`, `R22` | Reporting & Reconciliation | **< 5,000 ms** (R22 < 250 ms) |
| **P6** | Churn / win-back list calculation | Growth Marketing, CRM | `R09`, `R10`, `R18` | Reporting / Campaign Analytics | **< 5,000 ms** |
| **P7** | Trust & safety fraud scans | Risk Ops, Safety Team | `R24`, `R25` | Interactive Search & Ops | **< 250 ms** |
| **P8** | Deep pagination in admin console | Admin, Support Staff | `R16` | Interactive Ops & Search | **< 5 ms** |
| **P9** | Scalability of BI & growth dashboards | Executive Leadership, BI | `R06`, `R11`, `R12`, `R17`, `R21`, `R23` | Reporting / Executive OLAP | **< 5,000 ms** |

---

## 4. Key Architectural & Domain Assumptions

1. **Temporal & Geographic Context:** All operations occur within India Standard Time (`UTC+05:30` / `Asia/Kolkata`). All coordinates reside within Indian geographical boundaries (Lat: ~8°N–37°N, Lng: ~68°E–97°E).
2. **Trip Lifecycle State Machine:** A trip strictly follows the forward progression:  
   $$\text{REQUESTED} \longrightarrow \text{ACCEPTED} \longrightarrow \text{ONGOING} \longrightarrow \text{COMPLETED}$$  
   Alternatively, trips can transition to terminal states `CANCELLED_BY_RIDER` or `CANCELLED_BY_DRIVER` from appropriate intermediate stages.
3. **Active Data Skew:** At any given timestamp, active in-flight trips (`REQUESTED`, `ACCEPTED`, `ONGOING`) constitute less than 0.1% of the database (~300 out of 300,000 records). Historical trips (`COMPLETED`, `CANCELLED_*`) account for > 99.9% of total storage and are append-only / immutable.
4. **Financial Consistency & Immutability:** A completed trip must have exactly one corresponding payment record. Payment amounts and completed trip fares must remain strictly immutable to guarantee accounting and tax audit compliance.
5. **Read-to-Write Asymmetry:** The workload exhibits an estimated 85:15 read-to-write ratio across core transactions, and > 95:5 across user profiles and vehicle catalogs. Write transactions (`W01`–`W05`) must remain lean and not suffer excessive index maintenance overhead.
