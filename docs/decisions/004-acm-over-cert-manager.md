# ADR-004: ACM at the edge; cert-manager cut

**Status:** accepted
**Date:** 2026-09-07

## Context

TLS is required at the ingress. Options: ACM certificate on the ALB
listener (AWS-managed issuance/renewal) or in-cluster cert-manager issuing
into the cluster.

## Decision

ACM on the ALB. cert-manager is not installed.

## Consequences

- Edge TLS is a managed service with automatic renewal; nothing in-cluster
  consumes certificates today (east-west posture is ADR-006).
- cert-manager re-enters the picture only when a consumer exists — most
  plausibly as the workload-CA bridge if the mesh decision lands (AWS
  Private CA Connector for Kubernetes *requires* cert-manager).
- ExternalDNS is likewise cut: the ALB DNS name is the endpoint of record
  (assumption A4).
