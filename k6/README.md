# k6/ — performance regression gates

Load profiles and the baselines they are judged against. The performance
bonus requirement, made executable. **Landed (Phase 5, issue #5).**

## Layout

- `smoke.js` — the fixed load profile: two ramping-VU scenarios
  (`/articles`, `/tags` — the app's public permitAll routes), thresholds
  as sanity ceilings; the real gate is the baseline diff
- `baselines/dev.json` — committed p95/p99 baseline with seeding
  metadata; the versioned regression reference
- `tests/regression-fixture.json` — synthetic +20%-latency/2%-error
  fixture; `make perf-test` (and CI) proves the gate goes RED on it

## How the gate works

1. The perf job (or a post-dev-deploy runner with `BASE_URL` pointed at
   the real endpoint) runs the fixed profile via `k6 run`
2. `handleSummary()` exports `summary-handle.json` (run with
   `K6_SUMMARY_TREND_STATS="avg,p(95),p(99),count"` — k6 v2 omits
   p99/count from default trend stats)
3. `scripts/check-regression.sh` diffs p95 (fail at baseline × 1.15)
   and error rate (fail > 1% absolute) against the committed baseline;
   p99 is report-only
4. Breach → non-zero exit → the workflow fails

## Seeding / regenerating a baseline

`scripts/seed-baseline.sh <env> <base-url>` — runs the fixed profile
against a target and writes the baseline JSON (with metadata). The
baseline is committed; regeneration is a deliberate, PR-reviewed act.

## Scope note

The smoke profile targets the app's public routes (`/articles`, `/tags`).
Login-flow scenarios need seeded users + client credentials — deferred,
documented (see the P5 PR). The in-cluster rollout guard is the
AnalysisTemplate shipped with Phase 3 (ADR-005: k6 = pre-merge gate,
analysis = during-rollout guard).
