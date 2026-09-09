#!/usr/bin/env bash
# seed-baseline.sh — (re)generate the committed perf baseline deliberately.
#
# Runs the fixed k6 profile against a target, extracts per-scenario
# p95/p99/error-rate from summary-handle.json, and writes the baseline
# JSON (with metadata) to k6/baselines/<env>.json.
#
# Usage: scripts/seed-baseline.sh <env> <base-url> [commit]
# The baseline is COMMITTED — regeneration is a deliberate act, reviewed
# in a PR like any other change (issue #5: "how a baseline gets
# (re)generated deliberately").
set -euo pipefail

ENV_NAME="${1:?usage: seed-baseline.sh <env> <base-url> [commit]}"
BASE_URL="${2:?usage: seed-baseline.sh <env> <base-url> [commit]}"
COMMIT="${3:-$(git rev-parse --short HEAD 2>/dev/null || echo unknown)}"
K6="${K6:-$HOME/.local/bin/k6}"
OUT="k6/baselines/${ENV_NAME}.json"

cd "$(dirname "$0")/.."
mkdir -p k6/baselines

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

# Warm the target first — the baseline must represent steady-state,
# matching how perf.yml profiles (scripts/warmup-target.sh, shared).
"$(dirname "$0")/warmup-target.sh" "$BASE_URL" 90

echo "==> running fixed profile against $BASE_URL"
# v2 default trend stats omit p(99)/count — the baseline needs them
export K6_SUMMARY_TREND_STATS="avg,p(95),p(99),count"
BASE_URL="$BASE_URL" "$K6" run k6/smoke.js || { echo "k6 run failed" >&2; exit 1; }

# k6 --summary-export writes the raw summary; handleSummary writes our
# shaped one next to the cwd. Prefer the shaped one when present.
SUMMARY="summary-handle.json"
[ -f "$SUMMARY" ] || { echo "no summary-handle.json produced" >&2; exit 1; }

jq --arg env "$ENV_NAME" --arg url "$BASE_URL" --arg commit "$COMMIT" \
  --arg date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg k6ver "$("$K6" version | awk '{print $2}')" \
  --arg arch "$(uname -m)" \
  '{meta: {env: $env, target: $url, commit: $commit, seeded_at: $date, k6_version: $k6ver, arch: $arch,
           tolerance_p95: 1.15, note: "p95 gated at baseline x1.15 (D3); error rate gated at 1% absolute; p99 report-only. ARCH NOTE: cross-arch comparisons (e.g. arm64-seeded baseline vs amd64 CI) are accepted ONLY because the 1.15x tolerance absorbs the observed arch delta (+3.0%/+1.9%); re-seed on the comparison arch if margins ever approach the limit"},
    scenarios: .scenarios}' \
  "$SUMMARY" > "$OUT"

mv "$SUMMARY" "$WORKDIR/" 2>/dev/null || true

echo "==> baseline written: $OUT"
cat "$OUT"
