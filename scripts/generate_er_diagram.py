#!/usr/bin/env python3
"""
Generate publication-quality Entity-Relationship Diagram (ERD)
for the Uber Ride-Hailing Database in PDF and PNG formats.
Course: Database Management Systems (DE Project)
"""

import os
import subprocess
import sys

def build_pdf_stream():
    width = 2200
    height = 1400
    stream = []

    # Canvas Background
    stream.append("0.965 0.972 0.980 rg 0 0 2200 1400 re f")

    # Grid background lines
    stream.append("0.915 0.925 0.940 RG 0.75 w")
    for x in range(0, width, 50):
        stream.append(f"{x} 0 m {x} {height} l S")
    for y in range(0, height, 50):
        stream.append(f"0 {y} m {width} {y} l S")

    # Main Header Banner
    stream.append("0.11 0.15 0.22 rg 40 1305 2120 75 re f")
    stream.append("0.18 0.24 0.35 RG 2 w 40 1305 2120 75 re S")
    stream.append("BT /F1 22 Tf 1 1 1 rg 65 1347 Td (UBER RIDE-HAILING DATABASE -- ENTITY RELATIONSHIP DIAGRAM) Tj ET")
    stream.append("BT /F2 12.5 Tf 0.78 0.85 0.94 rg 65 1324 Td (Relational Schema in 3NF / BCNF | Multi-City Operational & Analytical Workload | PostgreSQL 15+) Tj ET")

    # Legend & Metadata Box
    stream.append("1 1 1 rg 1460 45 680 115 re f")
    stream.append("0.78 0.82 0.88 RG 1.5 w 1460 45 680 115 re S")
    stream.append("BT /F1 11.5 Tf 0.15 0.2 0.28 rg 1480 135 Td (SCHEMA CONVENTIONS & RELATIONSHIP CARDINALITIES) Tj ET")

    # Badges in legend
    badges = [
        (1480, 108, "PK", (0.85, 0.52, 0.10), "Primary Key"),
        (1590, 108, "FK", (0.15, 0.52, 0.82), "Foreign Key"),
        (1700, 108, "UQ", (0.28, 0.65, 0.35), "Unique Key"),
        (1810, 108, "NN", (0.45, 0.50, 0.58), "Not Null"),
    ]
    for bx, by, text, (br, bg, bb), desc in badges:
        stream.append(f"{br} {bg} {bb} rg {bx} {by-3} 24 13 re f")
        stream.append(f"BT /F1 8 Tf 1 1 1 rg {bx+4} {by} Td ({text}) Tj ET")
        stream.append(f"BT /F2 10.5 Tf 0.25 0.28 0.32 rg {bx+30} {by} Td ({desc}) Tj ET")

    stream.append("BT /F2 10.5 Tf 0.32 0.36 0.42 rg 1480 82 Td (1 --- N  One-to-Many  |  1 --- 0..1  One-to-Optional-One  |  1 --- 0..2  One-to-At-Most-Two) Tj ET")
    stream.append("BT /F2 10 Tf 0.48 0.52 0.58 rg 1480 60 Td (All primary & foreign keys maintain referential integrity. Schema qualified under 'uber' namespace.) Tj ET")

    # Table metadata: (name, category, (x, y_top, w, h), (hr, hg, hb), columns)
    tables = [
        {
            "name": "cities",
            "category": "Operational Reference",
            "rect": (400, 1260, 330, 245),
            "hcolor": (0.08, 0.44, 0.56),
            "cols": [
                (True, False, False, "city_id", "INT", "NOT NULL"),
                (False, False, True, "city_name", "VARCHAR(50)", "NOT NULL"),
                (False, False, False, "state", "VARCHAR(50)", "NOT NULL"),
                (False, False, False, "base_fare", "NUMERIC(6,2)", "NOT NULL"),
                (False, False, False, "per_km_rate", "NUMERIC(6,2)", "NOT NULL"),
                (False, False, False, "per_min_rate", "NUMERIC(6,2)", "NOT NULL"),
                (False, False, False, "launched_on", "DATE", "NOT NULL"),
            ]
        },
        {
            "name": "promo_codes",
            "category": "Marketing & Promotions",
            "rect": (50, 1260, 310, 220),
            "hcolor": (0.68, 0.32, 0.16),
            "cols": [
                (True, False, False, "promo_code", "VARCHAR(20)", "NOT NULL"),
                (False, False, False, "discount_pct", "INT", "NOT NULL"),
                (False, False, False, "max_discount", "NUMERIC(6,2)", "NOT NULL"),
                (False, False, False, "valid_from", "DATE", "NOT NULL"),
                (False, False, False, "valid_to", "DATE", "NOT NULL"),
                (False, False, False, "is_active", "BOOLEAN", "NOT NULL"),
            ]
        },
        {
            "name": "riders",
            "category": "Rider Accounts",
            "rect": (50, 975, 345, 270),
            "hcolor": (0.22, 0.35, 0.65),
            "cols": [
                (True, False, False, "rider_id", "INT", "NOT NULL"),
                (False, False, False, "full_name", "VARCHAR(100)", "NOT NULL"),
                (False, False, True, "email", "VARCHAR(150)", "NOT NULL"),
                (False, False, True, "phone", "VARCHAR(15)", "NOT NULL"),
                (False, True, False, "home_city_id", "INT", "NOT NULL"),
                (False, False, False, "signup_date", "DATE", "NOT NULL"),
                (False, False, False, "rider_rating", "NUMERIC(2,1)", "NULL"),
                (False, False, False, "is_active", "BOOLEAN", "NOT NULL"),
            ]
        },
        {
            "name": "drivers",
            "category": "Driver Partners",
            "rect": (1440, 1260, 340, 270),
            "hcolor": (0.16, 0.50, 0.36),
            "cols": [
                (True, False, False, "driver_id", "INT", "NOT NULL"),
                (False, False, False, "full_name", "VARCHAR(100)", "NOT NULL"),
                (False, False, True, "phone", "VARCHAR(15)", "NOT NULL"),
                (False, False, True, "license_no", "VARCHAR(30)", "NOT NULL"),
                (False, True, False, "city_id", "INT", "NOT NULL"),
                (False, False, False, "joined_on", "DATE", "NOT NULL"),
                (False, False, False, "driver_rating", "NUMERIC(2,1)", "NOT NULL"),
                (False, False, False, "status", "VARCHAR(20)", "NOT NULL"),
            ]
        },
        {
            "name": "vehicles",
            "category": "Fleet Registry",
            "rect": (1835, 1260, 325, 270),
            "hcolor": (0.46, 0.28, 0.60),
            "cols": [
                (True, False, False, "vehicle_id", "INT", "NOT NULL"),
                (False, True, False, "driver_id", "INT", "NOT NULL"),
                (False, False, True, "registration_no", "VARCHAR(20)", "NOT NULL"),
                (False, False, False, "make", "VARCHAR(50)", "NOT NULL"),
                (False, False, False, "model", "VARCHAR(50)", "NOT NULL"),
                (False, False, False, "manufacture_year", "INT", "NOT NULL"),
                (False, False, False, "vehicle_type", "VARCHAR(20)", "NOT NULL"),
                (False, False, False, "seat_capacity", "INT", "NOT NULL"),
            ]
        },
        {
            "name": "trips",
            "category": "Core Transaction Hub",
            "rect": (860, 1150, 490, 530),
            "hcolor": (0.10, 0.20, 0.36),
            "cols": [
                (True, False, False, "trip_id", "BIGINT", "NOT NULL"),
                (False, True, False, "rider_id", "INT", "NOT NULL"),
                (False, True, False, "driver_id", "INT", "NULL"),
                (False, True, False, "vehicle_id", "INT", "NULL"),
                (False, True, False, "city_id", "INT", "NOT NULL"),
                (False, True, False, "promo_code", "VARCHAR(20)", "NULL"),
                (False, False, False, "requested_at", "TIMESTAMPTZ", "NOT NULL"),
                (False, False, False, "pickup_at", "TIMESTAMPTZ", "NULL"),
                (False, False, False, "dropoff_at", "TIMESTAMPTZ", "NULL"),
                (False, False, False, "pickup_lat", "NUMERIC(9,6)", "NOT NULL"),
                (False, False, False, "pickup_lng", "NUMERIC(9,6)", "NOT NULL"),
                (False, False, False, "drop_lat", "NUMERIC(9,6)", "NOT NULL"),
                (False, False, False, "drop_lng", "NUMERIC(9,6)", "NOT NULL"),
                (False, False, False, "distance_km", "NUMERIC(6,2)", "NULL"),
                (False, False, False, "duration_min", "INT", "NULL"),
                (False, False, False, "surge_multiplier", "NUMERIC(3,2)", "NOT NULL"),
                (False, False, False, "fare_amount", "NUMERIC(8,2)", "NULL"),
                (False, False, False, "status", "VARCHAR(30)", "NOT NULL"),
            ]
        },
        {
            "name": "payments",
            "category": "Settlement & Audit",
            "rect": (380, 520, 360, 220),
            "hcolor": (0.18, 0.46, 0.32),
            "cols": [
                (True, False, False, "payment_id", "INT", "NOT NULL"),
                (False, True, True, "trip_id", "BIGINT", "NOT NULL"),
                (False, False, False, "amount", "NUMERIC(8,2)", "NOT NULL"),
                (False, False, False, "method", "VARCHAR(20)", "NOT NULL"),
                (False, False, False, "payment_status", "VARCHAR(20)", "NOT NULL"),
                (False, False, False, "paid_at", "TIMESTAMPTZ", "NOT NULL"),
            ]
        },
        {
            "name": "ratings",
            "category": "Service Quality Reviews",
            "rect": (1480, 520, 360, 195),
            "hcolor": (0.62, 0.42, 0.16),
            "cols": [
                (True, True, False, "trip_id", "BIGINT", "NOT NULL"),
                (True, False, False, "rated_by", "VARCHAR(10)", "NOT NULL"),
                (False, False, False, "stars", "SMALLINT", "NOT NULL"),
                (False, False, False, "comment", "VARCHAR(255)", "NULL"),
                (False, False, False, "created_at", "TIMESTAMPTZ", "NOT NULL"),
            ]
        }
    ]

    # Draw connection lines
    def draw_path(pts, label_start, label_end, color=(0.38, 0.44, 0.52), width_pt=2, style="solid"):
        r, g, b = color
        stream.append(f"{r} {g} {b} RG {width_pt} w")
        if style == "dashed":
            stream.append("[4 3] 0 d")
        else:
            stream.append("[] 0 d")

        stream.append(f"{pts[0][0]} {pts[0][1]} m")
        for x, y in pts[1:]:
            stream.append(f"{x} {y} l")
        stream.append("S")
        stream.append("[] 0 d")

        if label_start:
            stream.append(f"BT /F1 11 Tf 0.1 0.1 0.1 rg {pts[0][0]+6} {pts[0][1]+4} Td ({label_start}) Tj ET")
        if label_end:
            stream.append(f"BT /F1 11 Tf 0.1 0.1 0.1 rg {pts[-1][0]-18} {pts[-1][1]+4} Td ({label_end}) Tj ET")

    # Connectors
    draw_path([(550, 1015), (550, 915), (395, 915)], "1", "N")
    draw_path([(730, 1180), (790, 1180), (790, 1275), (1400, 1275), (1400, 1190), (1440, 1190)], "1", "N")
    draw_path([(730, 1130), (810, 1130), (810, 1045), (860, 1045)], "1", "N")
    draw_path([(360, 1210), (385, 1210), (385, 1275), (825, 1275), (825, 1020), (860, 1020)], "1", "0..N", style="dashed")
    draw_path([(395, 875), (860, 875)], "1", "N")
    draw_path([(1780, 1190), (1835, 1190)], "1", "N")
    draw_path([(1440, 1120), (1390, 1120), (1390, 955), (1350, 955)], "1", "0..N")
    draw_path([(1835, 1130), (1795, 1130), (1795, 925), (1350, 925)], "1", "0..N")
    draw_path([(950, 620), (950, 475), (740, 475)], "1", "0..1")
    draw_path([(1260, 620), (1260, 475), (1480, 475)], "1", "0..2")

    # Draw table cards
    for t in tables:
        x, y_top, w, h = t["rect"]
        hr, hg, hb = t["hcolor"]
        y_bot = y_top - h

        # Subtle card shadow
        stream.append(f"0.84 0.86 0.89 rg {x+4} {y_bot-4} {w} {h} re f")

        # White card body
        stream.append(f"1 1 1 rg {x} {y_bot} {w} {h} re f")
        stream.append(f"0.74 0.77 0.82 RG 1.5 w {x} {y_bot} {w} {h} re S")

        # Colored header block
        hh = 42
        stream.append(f"{hr} {hg} {hb} rg {x} {y_top-hh} {w} {hh} re f")
        t_name = t["name"].upper()
        stream.append(f"BT /F1 13.5 Tf 1 1 1 rg {x+14} {y_top-24} Td ({t_name}) Tj ET")
        cat_name = t["category"]
        stream.append(f"BT /F2 9.5 Tf 0.85 0.92 0.98 rg {x+14} {y_top-36} Td ({cat_name}) Tj ET")

        # Attribute rows
        col_y = y_top - hh - 18
        for is_pk, is_fk, is_uq, cname, ctype, cnull in t["cols"]:
            bx = x + 10
            if is_pk and is_fk:
                stream.append(f"0.85 0.52 0.10 rg {bx} {col_y-3} 18 12 re f")
                stream.append(f"BT /F1 7.5 Tf 1 1 1 rg {bx+2} {col_y} Td (PK) Tj ET")
                stream.append(f"0.15 0.52 0.82 rg {bx+20} {col_y-3} 18 12 re f")
                stream.append(f"BT /F1 7.5 Tf 1 1 1 rg {bx+22} {col_y} Td (FK) Tj ET")
                tx = bx + 43
            elif is_pk:
                stream.append(f"0.85 0.52 0.10 rg {bx} {col_y-3} 22 12 re f")
                stream.append(f"BT /F1 8 Tf 1 1 1 rg {bx+4} {col_y} Td (PK) Tj ET")
                tx = bx + 28
            elif is_fk:
                stream.append(f"0.15 0.52 0.82 rg {bx} {col_y-3} 22 12 re f")
                stream.append(f"BT /F1 8 Tf 1 1 1 rg {bx+4} {col_y} Td (FK) Tj ET")
                tx = bx + 28
            elif is_uq:
                stream.append(f"0.28 0.65 0.35 rg {bx} {col_y-3} 22 12 re f")
                stream.append(f"BT /F1 8 Tf 1 1 1 rg {bx+4} {col_y} Td (UQ) Tj ET")
                tx = bx + 28
            else:
                tx = bx + 4

            # Column name
            font = "/F1" if is_pk else "/F2"
            stream.append(f"BT {font} 10.5 Tf 0.15 0.18 0.22 rg {tx} {col_y} Td ({cname}) Tj ET")

            # Type and nullability on right
            type_str = f"{ctype}  {cnull}"
            stream.append(f"BT /F2 9 Tf 0.44 0.48 0.55 rg {x+w-122} {col_y} Td ({type_str}) Tj ET")

            # Row divider
            stream.append(f"0.92 0.93 0.95 RG 0.5 w {x+6} {col_y-7} m {x+w-6} {col_y-7} l S")
            col_y -= 25

    stream_bytes = "\n".join(stream).encode("utf-8")
    stream_len = len(stream_bytes)

    objects = [
        b"<< /Type /Catalog /Pages 2 0 R >>",
        b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        f"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 {width} {height}] /Contents 4 0 R /Resources << /Font << /F1 5 0 R /F2 6 0 R >> >> >>".encode("utf-8"),
        f"<< /Length {stream_len} >>\nstream\n".encode("utf-8") + stream_bytes + b"\nendstream",
        b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>",
        b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"
    ]

    out = bytearray(b"%PDF-1.4\n")
    offsets = []
    for i, obj in enumerate(objects, 1):
        offsets.append(len(out))
        out.extend(f"{i} 0 obj\n".encode("utf-8"))
        out.extend(obj)
        out.extend(b"\nendobj\n")

    xref_offset = len(out)
    out.extend(f"xref\n0 {len(objects)+1}\n".encode("utf-8"))
    out.extend(b"0000000000 65535 f \n")
    for off in offsets:
        out.extend(f"{off:010d} 00000 n \n".encode("utf-8"))

    out.extend(f"trailer\n<< /Size {len(objects)+1} /Root 1 0 R >>\nstartxref\n{xref_offset}\n%%EOF\n".encode("utf-8"))
    return out

def main():
    os.makedirs("diagrams", exist_ok=True)
    pdf_path = "diagrams/er_diagram.pdf"
    png_path = "diagrams/er_diagram.png"

    print("Building vector PDF...")
    pdf_data = build_pdf_stream()
    with open(pdf_path, "wb") as f:
        f.write(pdf_data)
    print(f"Saved: {pdf_path}")

    print("Rasterizing to high-resolution PNG using sips...")
    res = subprocess.run(["sips", "-s", "format", "png", pdf_path, "--out", png_path], capture_output=True, text=True)
    if res.returncode == 0:
        print(f"Saved: {png_path}")
    else:
        print(f"sips warning/error: {res.stderr}")

if __name__ == "__main__":
    main()
