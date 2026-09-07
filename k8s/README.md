# k8s/ — the manifests Argo CD delivers

The desired state of every workload, expressed as kustomize base + overlays.

**Layout**

- `backend/`, `frontend/`, `keycloak/` — each `base/` + `overlays/{dev,prod}`
- `analysis/` — AnalysisTemplates: the metric queries that gate canary promotion

**Contract**

- What Argo *delivers* lives here. Argo's *own configuration* lives in `../argocd/` — the separation is deliberate and must hold.
- Every workload ships the full hardening set: probes (readiness, liveness, startup for slow JVMs), PDB, topology spread, security context, NetworkPolicy.
- Image tags are set by CI (`kustomize edit set image`) — never by hand.
- Rendered output must pass `policies/` conftest rules before merge.
