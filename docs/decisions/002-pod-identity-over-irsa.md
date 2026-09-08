# ADR-002: EKS Pod Identity over IRSA

**Status:** accepted (revised twice — see Revision History)
**Date:** 2026-09-07

## Context

Pods need AWS credentials for exactly one purpose in this platform: the
Secrets Store CSI driver's AWS provider (ASCP) fetching from Secrets
Manager at mount time. Two mechanisms: IRSA (per-cluster OIDC provider +
trust-policy surgery per role) or EKS Pod Identity (role associations
bound to cluster/namespace/service-account).

## Critical mechanism note (verified in ASCP source, server/server.go)

ASCP resolves AWS identity from the **mounting pod's** service account —
never its own. The CSI mount request carries
`csi.storage.k8s.io/serviceAccount.name/.tokens`; with `usePodIdentity:
"true"` in the SecretProviderClass, ASCP exchanges the mounting SA's Pod
Identity token for credentials. Consequences:

- A controller- or provider-level association is **dead code** — the
  provider SA is never the identity.
- Associations must be **per workload** (backend, keycloak, db-bootstrap),
  provisioned in `modules/eks` via the root's `workload_associations` map,
  each bound to one shared read-scoped role.

## Decision

EKS Pod Identity. One IAM role (`modules/eks`), read-scoped by the CSI
policy (6 secret ARNs). Per-workload `aws_eks_pod_identity_association`
resources are provisioned in `modules/eks`, driven by the
`workload_associations` map instantiated at the root (`infra/eks.tf`);
the workloads' SecretProviderClasses set `usePodIdentity: "true"`.

## The accurate posture (replacing the earlier "zero IAM" claim)

Application pods: **no AWS credentials, no AWS SDK, no AWS API calls** —
they receive mounted files. Their service accounts carry one read-only
scoped association that ASCP borrows at mount time. That is the honest
boundary; "carries zero IAM" was unachievable under ASCP + Pod Identity.

- The credential surface stays enumerable: one role, one scoped policy,
  N small associations (one per mounting workload).
- IRSA remains the correct tool for Fargate profiles and some
  cross-account scenarios; documented as the known edge, not used here.

## Revision History

1. Original: "two consumers (LB controller, CSI driver)" — wrong; the LB
   controller is AWS-operated under Auto Mode, and no association existed.
2. First fix: association on the provider SA `csi-secrets-store-provider-aws`
   — correct SA name, dead target: ASCP authenticates as the mounting pod.
3. Current: per-workload associations (P3), shared read-scoped role,
   `usePodIdentity` in the SecretProviderClass. Verified against ASCP
   source and the AWS EKS Pod Identity docs.
