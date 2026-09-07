# argocd/ — Argo CD's own configuration

The GitOps control plane's definition: what Argo watches, who it syncs for, and when.

**Layout** (lands with Phase 3, `#3`)

- `projects/` — AppProject(s): scoping and destination rules
- `apps/dev/` — Applications pointing at `k8s/*/overlays/dev`, **auto-sync**
- `apps/prod/` — Applications pointing at `k8s/*/overlays/prod`, **sync gated** on promotion PR merge

**Contract**

- This directory configures Argo. It must never contain the payloads Argo delivers (`../k8s/`).
- Argo CD itself is installed by Terraform (`infra/modules/argocd`) — this directory takes over from first boot.
- Promotion = a PR moving an image tag between overlays. Nothing here or in CI pushes directly to a cluster.
