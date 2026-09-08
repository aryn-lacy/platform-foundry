# ADR-001: EKS Auto Mode over self-managed nodes

**Status:** accepted
**Date:** 2026-09-07

## Context

The platform needs a Kubernetes runtime. Options: EKS with self-managed
node groups (install and operate cluster-autoscaler/Karpenter, the AWS Load
Balancer Controller, storage drivers), or EKS **Auto Mode**, where AWS
operates node provisioning/consolidation, the load balancer controller,
block storage, and the Pod Identity agent as part of the service.

## Decision

EKS Auto Mode.

## Consequences

- Node lifecycle, scaling, and the ALB controller are AWS's problem; the
  platform's labor budget goes to the delivery system, not node babysitting.
- Cost premium per node-hour accepted in exchange for that labor — the
  explicit trade (see also the review note in PR #7: this repo optimizes
  for operational posture, not bill minimization).
- No node-level launch-template hardening (IMDS hop-limit): the AMI is
  AWS-managed. Pod Identity associations remain the only credential path
  and are stated as-is in the docs.
- Karpenter-specific tuning is unavailable; general-purpose node pools
  cover the workload classes this platform runs.
