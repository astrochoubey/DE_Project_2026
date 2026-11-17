#!/usr/bin/env bash
# Runs every query in queries/workload_30.sql with EXPLAIN (ANALYZE, BUFFERS)
# RUNS times (default 3), records the average and median execution time, and saves the raw plans.
#
# Usage:   ./benchmarks/run_benchmark.sh <database> <phase> [runs] [workload.sql]
# Example: ./benchmarks/run_benchmark.sh capstone baseline
#          ./benchmarks/run_benchmark.sh capstone optimized 3 sql/06_optimized_queries.sql
#
# Connection settings come from the usual libpq variables (PGHOST, PGPORT, PGUSER).
# Queries are split on "-- @R1" / "-- @W1" marker lines; "-- @END" stops collection.
#
# WRITE queries (W*) run inside BEGIN ... ROLLBACK, so your data does not change.
set -euo pipefail

DB="${1:?database name required}"
PHASE="${2:?phase required: baseline | optimized | large}"
RUNS="${3:-3}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORKLOAD="${4:-$ROOT/queries/workload_30.sql}"

if [[ ! -f "$WORKLOAD" ]]; then
  echo "Error: Workload file '$WORKLOAD' not found" >&2
  exit 1
fi

if ! [[ "$RUNS" =~ ^[1-9][0-9]*$ ]]; then
  echo "Error: RUNS must be a positive integer, got '$RUNS'" >&2
  exit 1
fi

OUT="$ROOT/benchmarks/results/$PHASE"
SUMMARY="$OUT/summary.csv"
mkdir -p "$OUT"
echo "query_id,type,avg_ms,median_ms,min_ms,max_ms,scan_nodes" > "$SUMMARY"

# Split the workload file on "-- @ID" markers into one temp file per query
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

awk -v dir="$TMP" '
  /^-- @/ { id = ""; if ($2 ~ /^@[RW][0-9]+$/) { id = substr($2, 2); file = dir "/" id ".sql"; printf "" > file }; next }
  id != "" && !/^--/ { print >> file }
' "$WORKLOAD"

shopt -s nullglob
files=("$TMP"/*.sql)
shopt -u nullglob

if [[ ${#files[@]} -eq 0 ]]; then
  echo "Error: No query definitions found in '$WORKLOAD'" >&2
  exit 1
fi

for f in $(printf '%s\n' "${files[@]}" | sort -V); do
  id="$(basename "$f" .sql)"
  type="READ"; [[ "$id" == W* ]] && type="WRITE"
  query="$(cat "$f")"
  times=()
  : > "$OUT/$id.txt"
  for ((i = 1; i <= RUNS; i++)); do
    if [[ "$type" == "WRITE" ]]; then
      sql="SET search_path TO uber; BEGIN; EXPLAIN (ANALYZE, BUFFERS) $query; ROLLBACK;"
    else
      sql="SET search_path TO uber; EXPLAIN (ANALYZE, BUFFERS) $query"
    fi
    plan="$(printf '%s\n' "$sql" | psql -d "$DB" -X -q -A -t -v ON_ERROR_STOP=1)"
    echo "=== $id run $i ===" >> "$OUT/$id.txt"
    echo "$plan" >> "$OUT/$id.txt"
    t="$(echo "$plan" | grep -oE 'Execution Time: [0-9.]+' | awk '{print $3}')"
    times+=("$t")
  done
  sorted=()
  while IFS= read -r line; do
    sorted+=("$line")
  done < <(printf '%s\n' "${times[@]}" | sort -g)
  median="${sorted[$((RUNS / 2))]}"
  avg="$(printf '%s\n' "${times[@]}" | awk '{ s += $1 } END { printf "%.3f", s / NR }')"
  # every scan node in the last run's plan, e.g. "Seq Scan on orders | Index Scan using customers_pkey on customers"
  node="$(echo "$plan" | grep -oE '(Parallel )?(Seq Scan|Index Scan|Index Only Scan|Bitmap Heap Scan|Bitmap Index Scan)( Backward)?( using [a-z0-9_]+)? on [a-z0-9_]+' | sed -E 's/Parallel //; s/ Backward//' | awk '!seen[$0]++' | paste -sd'|' - | sed 's/|/ | /g' || true)"
  # grep exits 1 when nothing matches (e.g. a plain INSERT); don't let set -e abort the run
  node="${node:-(no scan)}"
  echo "$id,$type,$avg,$median,${sorted[0]},${sorted[$((RUNS - 1))]},$node" >> "$SUMMARY"
  printf '%-4s %-5s avg %9s ms   %s\n' "$id" "$type" "$avg" "$node"
done

echo "Workload: $WORKLOAD"
echo "Saved raw plans and summary to $OUT"
