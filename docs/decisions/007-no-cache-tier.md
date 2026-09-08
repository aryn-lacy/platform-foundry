# ADR-007: No cache tier (yet)

**Status:** accepted
**Date:** 2026-09-07

## Context

A caching tier (ElastiCache) is a common "production-grade" checkbox.

## Decision

Do not provision one.

## Consequences

- The payload (RealWorld/Conduit) has zero cache dependencies; every
  request is served from the API + database. A cache here would be
  architecture cosplay — present for the diagram, serving nothing.
- The first workload with a real latency profile (sessions, rate-limit
  counters, hot reads) triggers this decision's reversal, documented the
  same way.
