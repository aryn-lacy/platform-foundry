# ADR-008: Two RDS instances — identity tier isolated from app tier

**Status:** accepted
**Date:** 2026-09-08

## Context

The platform needs PostgreSQL for the application **and** for Keycloak.
Options: one shared instance with two logical databases (cheaper — logical
databases are fully isolated namespaces), or two instances.

## Decision

Two instances: `platform-foundry-<env>-app` and
`platform-foundry-<env>-keycloak`. Identity-tier storage shares nothing
with application-tier storage: separate compute, storage, backup estates,
maintenance windows, and restore granularity.

## Consequences

- The IdP's availability and performance envelope are independent of
  application behavior; a pathological app query cannot starve Keycloak,
  and maintenance events do not couple the tiers.
- Costs roughly double — accepted: RDS is cheap, and this is a reference
  posture where the isolation story outweighs the (never-billed) cost.
- The alternative remains **documented, not erased**: a shared instance
  with logical database separation is the correct choice for genuinely
  cost-constrained deployments. This ADR records the trade, not a verdict
  against it.
- Bootstrap Job contract simplifies to **roles only**: each instance
  provisions its own database at creation; the Job creates the
  `realworld_app` and `keycloak` roles with their staged passwords.
