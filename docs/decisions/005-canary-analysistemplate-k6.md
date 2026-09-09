# ADR-005: Canary + AnalysisTemplate + k6 in CI

**Status:** accepted
**Date:** 2026-09-07

## Context

Performance-regression detection and safe rollouts. Options: plain
step-pause canary; metric-gated AnalysisTemplate (needs Prometheus);
k6 load profiles in CI; or combinations.

## Decision

Both, each honest about what it needs:

- **k6 in CI** — real and executable once P5 lands: fixed VU profiles with
  thresholds against a committed baseline; regression fails the build
  *before* rollout. Depends on nothing but the endpoint.
- **AnalysisTemplate** — declared in-cluster guard during rollout (P3):
  canary steps gated on error-rate/p95 queries against the **assumed**
  platform Prometheus (A3). The manifest ships with the workloads (k8s/analysis/);
  dependency documented, not hidden.

## Consequences

- The two cover different moments: pre-merge gate (k6) and during-rollout
  guard (analysis). Neither alone is the full story.
- k6-only with step-pause canary is the documented fallback if the
  observability plane is unavailable.
