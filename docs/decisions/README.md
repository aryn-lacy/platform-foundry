# decisions/ — architecture decision records

Numbered, dated, one decision each. Status: `accepted`, `superseded`, or `planned`.

| # | Decision | Status |
|---|----------|--------|
| 001 | [EKS Auto Mode over self-managed nodes](001-eks-auto-mode.md) | accepted |
| 002 | [EKS Pod Identity over IRSA](002-pod-identity-over-irsa.md) | accepted |
| 003 | [Terraform workspaces per landing zone](003-workspaces-per-landing-zone.md) | accepted |
| 004 | [ACM at the edge; cert-manager cut](004-acm-over-cert-manager.md) | accepted |
| 005 | [Canary + AnalysisTemplate + k6 in CI](005-canary-analysistemplate-k6.md) | accepted |
| 006 | [Mesh mTLS deferred](006-mesh-mtls-deferred.md) | accepted |
| 007 | [No cache tier (yet)](007-no-cache-tier.md) | accepted |
| 008 | [Two RDS instances — identity tier isolated from app tier](008-two-rds-instances.md) | accepted |
| 009 | [Hand-rolled modules over community sources](009-hand-rolled-modules.md) | accepted |
| 010 | [OpenTofu over Terraform](010-opentofu-over-terraform.md) | accepted |
| 011 | [k6 as the perf gate; how the baseline was seeded](011-k6-perf-gate-baseline.md) | accepted |

All eleven decisions are reflected in code where they live:
001/002 in `modules/eks` (Auto Mode config; Pod Identity role +
association), 003 in the root + `envs/`, 004 in the TLS posture (ACM at
the edge — the ALB itself is provisioned by Auto Mode's AWS-operated
controller), 005 in
`k8s/analysis/` (P3) + `k6/` (P5), 006 in the NetworkPolicy posture
(P3), 008 in `modules/database`, 009 in `infra/modules/README.md`, 010 in
`infra/versions.tf` + the Makefile, 011 in `k6/` + `scripts/` +
`.github/workflows/perf.yml`. (004's edge is ACM-by-ALB as provisioned;
the repository ships no ingress manifests — the workload's listener is
an exercise left to the deployer, consistent with the no-cloud-spend
posture.)
