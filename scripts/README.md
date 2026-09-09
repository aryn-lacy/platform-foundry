# scripts/ — helpers

## seed-baseline.sh

`(Re)generates the committed k6 perf baseline deliberately:`

```bash
scripts/seed-baseline.sh <env> <base-url> [commit]
```

Runs the fixed profile (`k6/smoke.js`) against the target, extracts
per-scenario p95/p99/error-rate, and writes `k6/baselines/<env>.json`
with seeding metadata (date, target, k6 version, commit). The baseline
is committed — regeneration is a PR-reviewed act.

## check-regression.sh

`The perf gate's judgment:`

```bash
scripts/check-regression.sh <summary-handle.json> <baseline.json> [tolerance]
```

- p95 per scenario: **FAIL** if current > baseline × tolerance (default 1.15)
- error rate per scenario: **FAIL** if > 1% absolute
- p99: report-only
- Breach exits 1 naming the metric; prints a comparison table
