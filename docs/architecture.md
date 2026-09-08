# platform-foundry — Architecture

A production-grade continuous delivery platform on AWS. This document is
the system's source of truth: what it is, how it is shaped, why, and what
is deliberately assumed rather than built.

Companion documents: [assumptions.md](assumptions.md) (the register),
[decisions/](decisions/) (ADRs 001–010), [runbooks/](runbooks/) (restore,
rollback).

---

## 1. Posture

**The platform is the product.** The application it deploys — a RealWorld
("Conduit") stack: Spring Boot API, Keycloak identity provider, React
frontend — is placeholder payload: realistic enough to exercise every part
of the delivery system, unimportant enough to swap for anything.

**Reference implementation.** The repository reads clone → bootstrap →
plan → apply runnable: pinned providers, documented variables, per-LZ
workspaces. It is a tenant workload stack, not a landing zone — the org
context it lands in is assumed ([assumptions A1–A2](assumptions.md)).

**Scope discipline.** Every deliberate non-feature (no mesh, no cache tier,
no ExternalDNS, no cert-manager) is a documented decision with its exit
ramp, never an omission. See the [decision log](decisions/README.md).

---

## 2. Context: landing zones

```
                     AWS ORGANIZATION (assumed)
  ┌────────────────────────────────────────────────────────────┐
  │  Transit Gateway hub · centralized egress · SCPs · DNS/IPAM │
  │                                                              │
  │  ┌───────────────────────┐      ┌───────────────────────┐   │
  │  │ DEV LANDING ZONE      │      │ PROD LANDING ZONE     │   │
  │  │ workload account      │      │ workload account      │   │
  │  │ workspace: dev        │      │ workspace: prod       │   │
  │  │                       │      │                       │   │
  │  │  this stack (1 code   │ ───▶ │  this stack (same     │   │
  │  │  path + dev tfvars)   │promo│  code + prod tfvars)   │   │
  │  └───────────────────────┘ PR   └───────────────────────┘   │
  └────────────────────────────────────────────────────────────┘
```

Two landing zones, one stack. `terraform workspace` selects the target;
the provider assumes a per-account role. Promotion is a pull request that
moves the image tag between overlays — the PR *is* the audit record.

---

## 3. The estate (Terraform — `infra/`)

OpenTofu ([ADR-010](decisions/010-opentofu-over-terraform.md)), one root,
hand-rolled modules ([ADR-009](decisions/009-hand-rolled-modules.md)).

- **Bootstrap** (`bootstrap/`) — the one documented manual step: versioned,
  encrypted, SSL-only S3 state bucket. Locking is S3-native
  (`use_lockfile`, OpenTofu ≥ 1.10) — no lock table exists.
- **Network** — VPC, 3 AZs, public/private subnets with Kubernetes
  discovery tags, single NAT gateway (documented dev-tier trade-off).
- **EKS** — **Auto Mode** ([ADR-001](decisions/001-eks-auto-mode.md)):
  nodes, load balancer controller, and storage are AWS-operated. Add-ons:
  `eks-pod-identity-agent`, `aws-secrets-store-csi-driver-provider`,
  `amazon-cloudwatch-observability`, community `metrics-server`, `adot`.
  Control plane: **private endpoint by default** (public access off unless an
  environment explicitly enables it with a CIDR allow-list). Workload identity:
  **Pod Identity, per workload via ASCP** — app pods hold no AWS
  credentials, ship no SDK, make no AWS calls; their service accounts
  carry read-scoped associations ASCP borrows at mount time
  ([ADR-002](decisions/002-pod-identity-over-irsa.md), revised).
- **Data** — **two RDS PostgreSQL Multi-AZ instances**
  ([ADR-008](decisions/008-two-rds-instances.md)): app tier and identity
  tier fully isolated — separate backup estates, maintenance windows,
  restore granularity. Daily automated backups per instance.
- **Secrets** — Secrets Manager, AWS-native end to end: per-tier DB
  credentials (staged for the bootstrap Job), Keycloak admin + client,
  per-tier break-glass master credentials (lifecycle-ignored: written
  once; rotation is a runbook operation). CSI read policy scoped to
  exactly six ARNs.
- **ECR** — immutable repos, scan-on-push, lifecycle policies.
- **Argo CD** — bootstrapped by Terraform (helm_release); everything after
  first boot is Argo-managed from `argocd/`.

Credential flow: `random_password` per instance → RDS password
(lifecycle-ignored) → materialized exactly once as the break-glass secret
→ Phase-3 bootstrap Job connects as master and creates the
`realworld_app` / `keycloak` roles with their staged passwords → pods run
least-privilege → masters return to break-glass duty.

---

## 4. The cluster (Argo CD — `argocd/` + `k8s/`)

Delivered by GitOps, not by CI pushing to clusters:

- **Argo CD app-of-apps** — Applications per workload per environment;
  dev auto-syncs, prod is gated on the promotion PR.
- **Namespaces** — `conduit` holds the application (backend + frontend);
  `keycloak` holds the identity tier. Namespace boundaries align with the
  NetworkPolicy and Pod Identity seams.
- **Workloads** — backend (Rollout, HPA, PDB, probes incl. JVM startup),
  frontend (same discipline), Keycloak (stock image, lean realm-as-code:
  realm + `realworld-backend` client + redirect URI).
- **Progressive delivery** — Argo Rollouts step-pause canary
  (20% → 5m → 50% → 5m → 100%) with an AnalysisTemplate guard against the
  platform Prometheus
  ([ADR-005](decisions/005-canary-analysistemplate-k6.md)).
- **Hardening** — default-deny NetworkPolicies with explicit allows
  (frontend→backend, backend→keycloak, backend/keycloak→their RDS tiers);
  security contexts; topology spread; PDBs on everything.
- **Secrets** — Secrets Store CSI + SecretProviderClasses (with
  `usePodIdentity: "true"`) mount what each pod needs at start; nothing
  secret-shaped in git.
- **Bootstrap Job** — one-shot, `k8s/bootstrap/`: connects to each RDS
  tier as master (CSI-mounted break-glass `db-master-<tier>`) and creates
  the `realworld_app` and `keycloak` roles with their staged passwords
  ([ADR-008](decisions/008-two-rds-instances.md)). Roles only — each
  instance provisions its own database.

### Workload identity contract (ADR-002, revised)

Pod Identity associations are **declarative bindings** — namespace +
service-account name + role ARN, held in the EKS control plane. Per AWS
docs, the referenced namespace/SA need not exist yet: the association is
inert until the first pod using that SA requests a token. Consequences:

- The associations live in the **EKS module** (`modules/eks`), driven by
  the root's `workload_associations` map (`infra/eks.tf`) and bound to the
  shared read-scoped role — applied before the workloads exist. No
  two-phase apply, no separate root — the binding semantics make the
  ordering a non-problem.
- **The contract:** renaming a workload service account is a two-file
  change — the k8s manifest *and* `infra/eks.tf`, in the same PR. A
  renamed SA with a stale association fails closed: the mount errors, it
  does not silently degrade.
- Image tags in manifests are `v0.0.0-placeholder` placeholders; CI's
  `kustomize edit set image` loop overwrites them. `latest` is banned
  (policies/ will enforce).

*(Manifests land with Phase 3; the contract above is fixed.)*

---

## 5. The pipeline (GitHub Actions — `.github/`)

```
 push (path-filtered)
   ├─ lint + unit ──► integration (Testcontainers: api+keycloak+pg)
   ├─ docker build (layered, 2 images) ──► trivy (fail on critical)
   ├─ push ECR (immutable tag)
   ├─ POLICY GATE: tfsec/checkov (infra) + conftest/OPA (manifests)
   └─ kustomize edit set image ──► commit   ← the deploy record

 dev overlay commit ──► Argo CD auto-sync ──► canary 20→50→100
                                              └─ AnalysisTemplate guard
 promotion PR (dev tag → prod overlay) ──► review+gates ──► prod canary

 post-deploy (dev): k6 profile vs committed baseline ──► fail on regression
```

CI holds **no cluster credentials** — every deployment is a commit the
cluster pulls. *(Workflows land with Phase 4; k6 with Phase 5.)*

---

## 6. Observability

Ship it, don't host it ([assumption A3](assumptions.md)):

- **Metrics/traces** — ADOT collector (AWS add-on) exports OTLP to the
  platform Prometheus; Spring (Micrometer) and Keycloak endpoints scraped.
- **Logs** — CloudWatch Observability add-on centralizes pod/node logs for
  every tier.
- **Judgment as code** — AnalysisTemplate queries and k6 thresholds define
  "healthy" and "fast enough" as versioned, executable config.

---

## 7. Security model

| Layer | Control |
|---|---|
| Workload identity | Pod Identity per workload (ASCP-borrowed); app pods = zero credentials, zero AWS calls ([ADR-002](decisions/002-pod-identity-over-irsa.md)) |
| Secrets | Secrets Manager + CSI (6-ARN read policy); break-glass masters lifecycle-frozen; nothing in git |
| Network | Private subnets; endpoint private by default (public opt-in + CIDR allow-list); default-deny east-west NPs; SG-scoped data tier; TLS terminates at ACM on the ALB |
| Supply chain | Immutable ECR tags; scan-on-push; Trivy gate in CI; dependabot |
| Policy | tfsec/checkov + conftest/OPA, pre-merge |
| Known boundary | East-west is plaintext inside the NP boundary — zero-trust roadmap: Istio ambient / VPC Lattice ([ADR-006](decisions/006-mesh-mtls-deferred.md)) |

---

## 8. Environments & promotion

| | dev | prod |
|---|---|---|
| Landing zone | dev account | prod account |
| Terraform | workspace `dev` + tfvars | workspace `prod` + tfvars |
| Sync | auto-sync | gated on PR |
| Analysis thresholds | loose | SLO-grade |
| Entry | merge to main → CI → set-image commit | promotion PR moving the tag |

---

## 9. Repository layout

```
apps/        placeholder payload (path-filtered CI)
infra/       OpenTofu estate (bootstrap, modules, envs)
k8s/         manifests Argo delivers (base + overlays)     [P3]
argocd/      Argo CD's own configuration                   [P3]
policies/    conftest/OPA rules + fixtures                 [P4]
k6/          load profiles + versioned baselines           [P5]
.github/     workflows                                      [P4/P5]
scripts/     helpers (baseline seeding, rendering)
docs/        this document, assumptions, ADRs, runbooks, diagrams
```

---

## 10. Roadmap (documented next steps, in order of value)

1. Zero-trust east-west: Istio ambient or VPC Lattice (ADR-006)
2. Cache tier when a workload earns it (ADR-007)
3. Per-AZ NAT for prod HA (network module trade-off note)
4. Terraform plan/apply automation in CI (Digger-class apply-on-merge)
5. Add-on version pinning policy (currently EKS-resolved; deliberate)

---

*Diagrams-as-code sources land in `docs/diagrams/` with Phase 6 follow-up;
the ASCII diagrams above are the normative layout in the interim.*
