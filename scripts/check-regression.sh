#!/usr/bin/env bash
# check-regression.sh — the perf gate's judgment (issue #5).
#
# Diffs a k6 summary-handle.json against a committed baseline:
#   - FAILS CLOSED: every baseline scenario must be present in the
#     summary with data (p95, error_rate != null; count > 0) — missing
#     metrics are a failure, never a pass (round-1 finding 1, round-2 minor)
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

# --- Fail closed: presence + data checks BEFORE any comparison ---
missing=0
for scenario in $(jq -r '.scenarios | keys[]' "$BASELINE"); do
  if ! jq -e --arg s "$scenario" '.scenarios[$s]' "$SUMMARY" >/dev/null; then
    echo "FAIL-CLOSED: scenario '$scenario' missing from summary — refusing to judge incomplete data" >&2
    missing=1
    continue
  fi
  p95=$(jq -r --arg s "$scenario" '.scenarios[$s].p95' "$SUMMARY")
  count=$(jq -r --arg s "$scenario" '.scenarios[$s].count // 0' "$SUMMARY")
  err=$(jq -r --arg s "$scenario" '.scenarios[$s].error_rate' "$SUMMARY")
  if [ "$p95" = "null" ] || [ -z "$p95" ]; then
    echo "FAIL-CLOSED: scenario '$scenario' has no p95 in summary — no data, no verdict" >&2
    missing=1
  elif [ "$err" = "null" ] || [ -z "$err" ]; then
    echo "FAIL-CLOSED: scenario '$scenario' has no error_rate in summary — no data, no verdict" >&2
    missing=1
  elif [ "$count" -le 0 ] 2>/dev/null; then
    echo "FAIL-CLOSED: scenario '$scenario' has count=$count — zero samples cannot clear a gate" >&2
    missing=1
  fi
done
[ "$missing" -eq 0 ] || { echo "PERF GATE: incomplete summary (see above) — failing closed" >&2; exit 1; }

fail=0
printf '%-10s %10s %10s %10s %10s %8s %10s\n' \
  scenario metric baseline limit current verdict margin

for scenario in $(jq -r '.scenarios | keys[]' "$BASELINE"); do
  for metric in p95 error_rate; do
    base=$(jq -r ".scenarios[\"$scenario\"].$metric // 0" "$BASELINE")
    cur=$(jq -r ".scenarios[\"$scenario\"].$metric // 0" "$SUMMARY")

    if [ "$metric" = p95 ]; then
      limit=$(awk -v b="$base" -v t="$TOLERANCE" 'BEGIN{printf "%.2f", b*t}')
      verdict=OK
      awk -v c="$cur" -v l="$limit" 'BEGIN{exit !(c > l)}' && verdict=BREACH
      margin=$(awk -v c="$cur" -v b="$base" 'BEGIN{printf "%+.1f%%", (c-b)/b*100}')
      [ "$verdict" = BREACH ] && fail=1
    else
      limit="0.01000"
      verdict=OK
      awk -v c="$cur" -v l=0.01 'BEGIN{exit !(c > l)}' && verdict=BREACH
      # percentage POINTS (rate delta), not a ratio — labeled to avoid
      # reading as a percent change
      margin=$(awk -v c="$cur" -v b="$base" 'BEGIN{printf "%+.2fpp", (c-b)*100}')
      [ "$verdict" = BREACH ] && fail=1
    fi

    printf '%-10s %10s %10.2f %10.2f %10.2f %8s %10s\n' \
      "$scenario" "$metric" "$base" "$limit" "$cur" "$verdict" "$margin"
  done

  # p99 report-only
  base99=$(jq -r ".scenarios[\"$scenario\"].p99 // 0" "$BASELINE")
  cur99=$(jq -r ".scenarios[\"$scenario\"].p99 // 0" "$SUMMARY")
  margin99=$(awk -v c="$cur99" -v b="$base99" 'BEGIN{printf "%+.1f%%", (c-b)/b*100}')
  printf '%-10s %10s %10.2f %10s %10.2f %8s %10s\n' \
    "$scenario" p99 "$base99" "(report)" "$cur99" INFO "$margin99"
done

if [ "$fail" -ne 0 ]; then
  echo "PERF GATE: REGRESSION — p95 beyond ${TOLERANCE}x baseline or error rate > 1%" >&2
  exit 1
fi
echo "PERF GATE: green — within tolerance"
