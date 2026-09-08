# Assumptions Register

What this repository **assumes** versus what it **builds**. Every assumed
dependency is deliberate, documented here, and traced to where it appears
in the architecture. Nothing silent.

| # | Assumption | Why it's out of scope | Where it appears |
|---|-----------|----------------------|------------------|
| A1 | Multi-account AWS org; dev and prod are **separate landing zones** (accounts) with a network hub | Org plumbing (TGW hub, centralized egress, SCPs) is platform-org territory; this stack is a well-behaved tenant | Fig. 1 context diagram · ADR-003 · `infra/envs/*.tfvars` (role ARN per LZ) |
| A2 | Landing-zone network services: Transit Gateway attachment, centralized DNS (Route 53), IPAM-delegated address space, inspection/egress | Same as A1 — consumed, not provisioned | Fig. 1 · network module comments (`vpc_cidr` description) |
| A3 | Platform **Prometheus + Grafana** exist as a shared observability plane | Metrics/traces are shipped (ADOT/OTLP), not hosted in-cluster; dashboards and SLO alerting live on the platform plane | Observability section · AnalysisTemplates (P3 deliverable) · ADR-005 |
| A4 | A public DNS zone exists and could be delegated to the workload | ExternalDNS deliberately cut — the ALB DNS name is the endpoint of record | ADR-004 · roadmap |
| A5 | Git credentials for Argo CD (deploy key/token) are provisioned out-of-band | Repo credentials are a secret-management process, not a Terraform resource | `infra/variables.tf` comment at the removal site · `infra/modules/argocd` |
| A6 | No cache tier is required by the payload | The RealWorld application has zero cache dependencies; ElastiCache would be undifferentiated add-on | ADR-007 · roadmap |
| A7 | East-west traffic is plaintext inside a default-deny NetworkPolicy boundary | Zero-trust (mesh mTLS) is a documented roadmap decision with named options, not a half-installed control plane | ADR-006 · security section |

## Honesty posture

This is a **reference implementation**: the repository reads as deployable —
pinned providers, documented variables, one documented bootstrap step — but
it is not applied against live accounts from CI. Two-phase apply ordering
(cluster, then Argo CD bootstrap) and placeholder landing-zone role ARNs are
stated in-line where a reader will meet them, not hidden.
