#!/usr/bin/env bash
# check-regression.sh — the perf gate's judgment (issue #5).
#
# Diffs a k6 summary-handle.json against a committed baseline:
#   - p95 per scenario: FAIL if current > baseline x tolerance (default 1.15)
#   - error rate per scenario: FAIL if current > 0.01 absolute
#   - p99: reported, not gated (noisy at low VU counts; D3)
# Exits 1 naming the breached metric; prints a comparison table.
#
# Usage: scripts/check-regression.sh <summary-handle.json> <baseline.json> [tolerance]
set -euo pipefail

SUMMARY="${1:?usage: check-regression.sh <summary.json> <baseline.json> [tolerance]}"
BASELINE="${2:?usage: check-regression.sh <summary.json> <baseline.json> [tolerance]}"
TOLERANCE="${3:-1.15}"

[ -f "$SUMMARY" ] || { echo "summary not found: $SUMMARY" >&2; exit 2; }
[ -f "$BASELINE" ] || { echo "baseline not found: $BASELINE" >&2; exit 2; }

fail=0
printf '%-10s %10s %14s %14s %8s %10s %8s\n' \
  scenario metric baseline limit current verdict margin

for scenario in $(jq -r '.scenarios | keys[]' "$BASELINE"); do
  for metric in p95 error_rate; do
    base=$(jq -r ".scenarios[\"$scenario\"].$metric // 0" "$BASELINE")
    cur=$(jq -r ".scenarios[\"$scenario\"].$metric // 0" "$SUMMARY")

    if [ "$metric" = p95 ]; then
      limit=$(jq -r "($base // 0) * $TOLERANCE" "$BASELINE" 2>/dev/null || echo "$base")
      limit=$(awk -v b="$base" -v t="$TOLERANCE" 'BEGIN{printf "%.2f", b*t}')
      verdict=OK
      awk -v c="$cur" -v l="$limit" 'BEGIN{exit !(c > l)}' && verdict=BREACH
      margin=$(awk -v c="$cur" -v b="$base" 'BEGIN{printf "%+.1f%%", (c-b)/b*100}')
      [ "$verdict" = BREACH ] && fail=1
    else
      limit="0.01000"
      verdict=OK
      awk -v c="$cur" -v l=0.01 'BEGIN{exit !(c > l)}' && verdict=BREACH
      margin=$(awk -v c="$cur" -v b="$base" 'BEGIN{printf "%+.2f", (c-b)}')
      [ "$verdict" = BREACH ] && fail=1
    fi

    printf '%-10s %10s %14.2f %14.2f %8.2f %10s %8s\n' \
      "$scenario" "$metric" "$base" "$limit" "$cur" "$verdict" "$margin"
  done

  # p99 report-only
  base99=$(jq -r ".scenarios[\"$scenario\"].p99 // 0" "$BASELINE")
  cur99=$(jq -r ".scenarios[\"$scenario\"].p99 // 0" "$SUMMARY")
  margin99=$(awk -v c="$cur99" -v b="$base99" 'BEGIN{printf "%+.1f%%", (c-b)/b*100}')
  printf '%-10s %10s %14.2f %14s %8.2f %10s %8s\n' \
    "$scenario" p99 "$base99" "(report)" "$cur99" INFO "$margin99"
done

if [ "$fail" -ne 0 ]; then
  echo "PERF GATE: REGRESSION — p95 beyond ${TOLERANCE}x baseline or error rate > 1%" >&2
  exit 1
fi
echo "PERF GATE: green — within tolerance"
