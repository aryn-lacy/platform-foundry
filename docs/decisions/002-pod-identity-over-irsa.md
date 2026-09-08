# ADR-002: EKS Pod Identity over IRSA

**Status:** accepted
**Date:** 2026-09-07

## Context

Pods and cluster controllers need AWS credentials. Two mechanisms: IRSA
(per-cluster OIDC provider + trust-policy surgery per role) or EKS Pod
Identity (role associations bound to cluster/namespace/service-account).

## Decision

EKS Pod Identity, for controllers only. Application pods carry **zero AWS
IAM credentials** — their secrets arrive via the Secrets Store CSI driver,
not via IAM.

## Consequences

- No OIDC provider resource, no trust-policy editing; roles are plain IAM
  roles associated via `aws_eks_pod_identity_association`.
- The credential surface is exactly two consumers (load balancer
  controller, CSI driver) — enumerable and auditable.
- IRSA remains the correct tool for Fargate profiles and some cross-account
  scenarios; documented as the known edge, not used here.
