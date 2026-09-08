# ADR-002: EKS Pod Identity over IRSA

**Status:** accepted
**Date:** 2026-09-07

## Context

Pods and cluster controllers need AWS credentials. Two mechanisms: IRSA
(per-cluster OIDC provider + trust-policy surgery per role) or EKS Pod
Identity (role associations bound to cluster/namespace/service-account).

Implementation note: this repository currently provisions the controller
role and its scoped policy; the association resource
(`aws_eks_pod_identity_association`) pins to the CSI add-on's
`kube-system/secrets-store-csi-driver` service account.

## Decision

EKS Pod Identity, for controllers only. Application pods carry **zero AWS
IAM credentials** — their secrets arrive via the Secrets Store CSI driver,
not via IAM.

## Consequences

- No OIDC provider resource, no trust-policy editing; roles are plain IAM
  roles bound with `aws_eks_pod_identity_association` (provisioned in
  `modules/eks` for the CSI driver's service account).
- Exactly **one** Pod Identity consumer: the Secrets Store CSI driver. The
  load balancer controller is AWS-operated under Auto Mode and holds no
  pod-identity association. The credential surface is enumerable and
  auditable: one role, one association, one scoped policy.
- IRSA remains the correct tool for Fargate profiles and some cross-account
  scenarios; documented as the known edge, not used here.
