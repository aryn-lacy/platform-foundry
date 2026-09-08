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

All ten decisions are reflected in code where they live:
001/002 in `modules/eks`, 003 in the root + `envs/`, 004 in `modules/eks`
(ACM listener) and the add-on set, 005 in `k8s/analysis/` (P3) + `k6/` (P5),
006 in the NetworkPolicy posture, 008 in `modules/database`, 009 in
`infra/modules/README.md`, 010 in `infra/versions.tf` + the Makefile.
