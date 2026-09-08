# argocd/ — Argo CD's own configuration

The GitOps control plane's definition: what Argo watches, and when it syncs.

**Layout**

- `projects/platform-foundry.yaml` — AppProject: source repos, destination
  namespaces, resource whitelist
- `apps/dev/` — Applications → `k8s/*/overlays/dev`, **auto-sync**
  (prune + selfHeal)
- `apps/prod/` — Applications → `k8s/*/overlays/prod`, **gated** — no
  automated sync; the promotion PR merge is the trigger, sync is approved

**Contract**

- This directory configures Argo. It must never contain the payloads Argo
  delivers (`../k8s/`).
- Argo CD itself is installed by Terraform (`infra/modules/argocd`) — this
  tree takes over from first boot.
- Promotion = a PR moving an image tag between overlays. Nothing here or
  in CI pushes directly to a cluster.
