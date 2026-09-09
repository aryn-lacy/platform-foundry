#!/usr/bin/env bash
# warmup-target.sh — bring a freshly-booted JVM target to steady-state
# before profiling (P5 round-2 finding 1).
#
# The committed baseline was seeded from a WARM stack; profiling a cold
# one compares JIT-cold latency against JIT-warm reference and breaches
# (~5x tolerance observed). Both perf.yml and seed-baseline.sh run this
# SAME script so measurement conditions are identical everywhere:
# warmup is part of the procedure, not an afterthought.
#
# Usage: scripts/warmup-target.sh <base-url> [seconds]
set -euo pipefail

BASE_URL="${1:?usage: warmup-target.sh <base-url> [seconds]}"
SECONDS_TO_WARM="${2:-90}"

echo "==> warming ${BASE_URL} for ${SECONDS_TO_WARM}s (JIT steady-state)"
end=$((SECONDS + SECONDS_TO_WARM))
requests=0
while [ $SECONDS -lt $end ]; do
  curl -sm 5 -o /dev/null "$BASE_URL/tags" || true
  curl -sm 5 -o /dev/null "$BASE_URL/articles?limit=10" || true
  requests=$((requests + 2))
  sleep 1
done
echo "==> warm: ${requests} requests over ${SECONDS_TO_WARM}s"
