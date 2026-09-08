# ADR-002: EKS Pod Identity over IRSA

**Status:** accepted
**Date:** 2026-09-07

## Context

Pods and cluster controllers need AWS credentials. Two mechanisms: IRSA
(per-cluster OIDC provider + trust-policy surgery per role) or EKS Pod
Identity (role associations bound to cluster/namespace/service-account).

Implementation note: the association resource
(`aws_eks_pod_identity_association`) pins to the ASCP provider's
`kube-system/csi-secrets-store-provider-aws` service account — the
component that performs the Secrets Manager API calls.

## Decision

EKS Pod Identity, for controllers only. Application pods carry **zero AWS
IAM credentials** — their secrets arrive via the Secrets Store CSI driver,
not via IAM.

## Consequences

- No OIDC provider resource, no trust-policy editing; roles are plain IAM
  roles bound with `aws_eks_pod_identity_association` (provisioned in
  `modules/eks` for the CSI driver's service account).
- Exactly **one** Pod Identity consumer: the ASCP provider
  (`csi-secrets-store-provider-aws`, kube-system) — the component that
  calls `secretsmanager:GetSecretValue`. The base CSI driver makes no AWS
  API calls; the load balancer controller is AWS-operated under Auto Mode
  and holds no association. Provider-level association (not per-pod
  `usePodIdentity`) keeps ADR-002's posture intact: app pods carry no AWS
  IAM at all; the provider fetches on their behalf. Credential surface:
  one role, one association, one scoped policy.
- IRSA remains the correct tool for Fargate profiles and some cross-account
  scenarios; documented as the known edge, not used here.
