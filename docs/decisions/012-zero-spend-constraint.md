# ADR-012: Zero AWS spend as a design constraint

**Status:** accepted
**Date:** 2026-09-10

## Context

This repository originated as a take-home assignment with one explicit
constraint: **no AWS spend**. Unlike the other decisions recorded here,
this one was handed to the project rather than chosen by it — but it
shaped the estate as much as any decision below, so it is recorded with
the same discipline instead of being left as negative space a reader has
to reverse-engineer.

## Decision

Treat zero-spend as a first-class architectural constraint and let its
consequences propagate honestly through the stack:

- **No live environment.** The Terraform is complete and reviewable, but
  nothing is applied from CI and no billable resources exist. The
  Honesty posture in `docs/assumptions.md` states this as-is.
- **No Ingress/DNS in the estate**, therefore no publicly reachable dev
  endpoint. The k6 perf gate therefore profiles the deployable image
  against a local stack in CI rather than a deployed cluster (see the
  `perf.yml` header for the exact semantics).
- **The canary's runtime guard is error-rate only.** Latency is gated
  pre-deploy in CI against the committed baseline, never against live
  traffic — because there is no live traffic to measure.

## Consequences

- The estate is code-as-artifact: every claim in this repository is
  verifiable without an AWS account, which is also what makes it useful
  as a reference implementation.
- Latency regressions caused by deployment topology (ALB, network
  fabric, database round-trips) are invisible to every gate in this
  repository. That is a known, bounded blind spot — recorded here so it
  is a documented scope line, not a surprise.
- First changes with a budget, in order: (1) a dev landing zone with
  ExternalDNS to produce a reachable endpoint, (2) the same k6 profile
  run post-deploy against dev as a release gate, (3) a latency
  AnalysisTemplate added beside error-rate on the canary.
- Every other tradeoff documented in this repository is engineering
  judgment, not budget.
