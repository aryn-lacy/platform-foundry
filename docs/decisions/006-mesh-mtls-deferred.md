# ADR-006: Mesh mTLS deferred

**Status:** accepted
**Date:** 2026-09-07

## Context

East-west traffic inside the cluster is plaintext, segmented by
default-deny NetworkPolicies. Zero-trust (pod-to-pod mTLS) would require a
mesh and a workload CA.

## Decision

Defer the mesh; ship the segmentation boundary now. The upgrade path is
named: **Istio ambient** or **VPC Lattice**, workload CA via istiod or AWS
Private CA Connector. **AWS App Mesh is not a candidate** — AWS support
ends 2026-09-30.

## Consequences

- The security boundary today is network-level (NetworkPolicies) plus
  IAM-level (Pod Identity, CSI-scoped secrets) — stated, not accidental.
- Hand-rolling mTLS without a mesh (cert-manager + custom issuance) was
  rejected outright: operating a CA is the exact operational load meshes
  exist to remove.
- Reviewer-facing claim is precise: "we know where the east-west is
  cleartext and why, and here is the line item that fixes it."
