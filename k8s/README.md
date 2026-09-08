# k8s/ — the manifests Argo CD delivers

The desired state of every workload, expressed as kustomize base + overlays.

**Namespaces:** `conduit` holds the application (backend + frontend);
`keycloak` holds the identity tier.

**Layout**

- `backend/` — Rollout (canary 20% → 5m → 50% → 5m → 100%), Service, HPA,
  PDB, NetworkPolicy, SecretProviderClass (`usePodIdentity: "true"`),
  ServiceAccount, security contexts, probes (readiness/liveness/startup —
  the JVM needs the startup probe)
- `frontend/` — same discipline (nginx; no DB, no secrets to mount)
- `keycloak/` — stock image Deployment, lean realm-as-code ConfigMap
  (realm + `realworld-backend` client + redirect URI), startup probe,
  Service; `keycloak` database credentials via its SecretProviderClass
- `analysis/` — AnalysisTemplates: the metric queries that gate canary
  promotion (error rate, p95) against the **assumed** platform Prometheus
- `bootstrap/` — the one-shot roles-only Job: connects to each RDS tier
  as master (CSI-mounted break-glass secrets) and creates the
  `realworld_app` / `keycloak` roles with their staged passwords
- `overlays/{dev,prod}` per workload — image tags, replica counts,
  analysis thresholds

**Contracts**

- What Argo *delivers* lives here. Argo's *own configuration* lives in
  `../argocd/` — the separation is deliberate and must hold.
- Every workload ships the full hardening set: probes, PDB, topology
  spread, security context, NetworkPolicy.
- Image tags are `v0.0.0-placeholder`; CI's `kustomize edit set image`
  writes real tags. `latest` is banned.
- SecretProviderClasses set `usePodIdentity: "true"`; workload SAs carry
  the Pod Identity associations defined in `infra/eks.tf` (ADR-002).
  Renaming an SA is a two-file change: its manifest here AND `infra/eks.tf`
  in the same PR.
- Rendered output must pass `policies/` conftest rules before merge.
- NetworkPolicy `ipBlock` CIDRs (VPC/ALB ingress, RDS egress) carry a
  `10.0.0.0/8` placeholder in base — overlays or the landing zone resolve
  them; a wrong-but-explicit CIDR beats a silent allow-all.
- AnalysisTemplates deploy into `conduit` (namespace-scoped resources must
  land where the Rollouts that reference them live).
- Spring env keys (`SPRING_DATASOURCE_*`) are the app-side contract with
  the synced Secret — verify against the payload image's configuration
  when apps/ lands (P4 CI smoke tests will prove it end-to-end).
