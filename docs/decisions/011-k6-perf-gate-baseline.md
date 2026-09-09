# ADR-011: k6 as the perf gate; how the baseline was seeded

**Status:** accepted
**Date:** 2026-09-09

## Context

ADR-005 committed to "k6 in CI" as the pre-rollout performance-regression
gate but deferred the mechanics. This record covers the two decisions
that landing it (issue #5) actually required: the tool, and — harder —
what a *trustworthy baseline* means for a latency gate.

Requirements: runs in CI with zero cloud credentials; fails the build on
regression; produces machine-readable metrics; scriptable (the gate is
code, reviewed like code); single binary, no cluster dependency.

## Decision

### Tool: k6

k6 over the field, for the gate's specific job:

- **JMeter**: the historical default, but GUI/XML test plans and JVM
  startup fight CI embedding; it's built for QA-team perf projects, not
  pipelines.
- **Gatling / Locust / Artillery**: credible (JVM-scale, Python, Node
  respectively) — right picks when the load logic wants to live in the
  team's language. None beats k6 at thresholds-as-code + non-zero exit +
  one static binary.
- **k6**: JavaScript scenarios (reviewable diffs), built-in threshold
  semantics, `handleSummary()` for machine-readable output, Grafana
  stewardship. Won the cloud-native CI niche for a reason.

The deciding factors were the exit-code contract (regression → build
failure, no human interpretation step) and the summary being shaped in
code rather than scraped from stdout.

### Metric contract

- **p95 per scenario is the gated metric**: 95% of requests at-or-below
  the value; the tail matters because latency averages lie (see any SLO
  written in the last decade). Gate: current > baseline × **1.15** fails.
- **Error rate gated absolutely**: > 1% fails regardless of baseline.
- **p99 reported, not gated**: at this profile's VU counts the p99
  sample is too thin — run-to-run jitter would false-alarm. Revisit if
  the profile scales up.

### Baseline methodology (the part that was actually hard)

A regression gate is only as trustworthy as its reference. The rules the
implementation enforces:

1. **Synthetic, fixed load.** The profile (`k6/smoke.js`) never varies
   per run. Real traffic isn't reproducible; a diff between runs must
   measure the artifact, not the traffic or the hour.
2. **Warm before measuring.** The committed baseline is a steady-state
   reference: `scripts/warmup-target.sh` (90 s of load) runs before both
   seeding and CI measurement. Empirical motivation: a cold-JVM target
   measured **+78% p95** against the warm baseline — 5× the tolerance —
   with zero code change. Warmup is a shared procedure called
   identically by `perf.yml` and `seed-baseline.sh`; conditions match by
   construction, not by luck.
3. **Baselines are committed, deliberately.** `seed-baseline.sh` writes
   `k6/baselines/<env>.json` with metadata (target, commit, k6 version,
   arch, date); regeneration is a PR-reviewed act, because silently
   changing the baseline changes what "regression" means.
4. **The gate fails closed.** Missing scenario, null metric, or zero
   sample count in a summary is a failure, never a pass. The gate
   detects *any artifact change* — code, dependency, config, environment
   — which is exactly why incomplete data must not read as "no
   regression".
5. **The gate proves it can go red.** `k6/tests/regression-fixture.json`
   (+20% p95, 2% errors, regenerated from the baseline by a documented
   transform) must FAIL the gate; CI and `make perf-test` assert this on
   every run. A gate that has never failed is untested.

Known, accepted limits: the baseline records `arch` — cross-arch
comparisons (arm64-seeded baseline vs amd64 runner) ride inside the
tolerance with the observed delta documented (~3%); re-seed on the
comparison arch if margins ever approach the limit. A new scenario
added to `smoke.js` but absent from the baseline is ungated until
baselined (the reverse direction fails closed).

## Consequences

- Perf regressions in *anything deployable* — features, refactors,
  dependency bumps, config, environment drift — fail the build before
  promotion, with the offending metric named.
- Environmental variance is pinned by procedure (warmup, fixed profile,
  metadata), not eliminated; the baseline is a contract about conditions
  as much as numbers.
- The in-cluster during-rollout guard remains the AnalysisTemplate
  (ADR-005's split: controlled experiment vs field trial).
- k6 v2 requires `K6_SUMMARY_TREND_STATS="avg,p(95),p(99),count"` —
  default trend stats omit p99/count. Wired in `perf.yml` and
  `seed-baseline.sh`; noted here because it will bite anyone who runs a
  bare `k6 run` and wonders where p99 went.
