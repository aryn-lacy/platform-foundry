# scripts/ — helper contracts

Small, documented, idempotent utilities. Everything here is safe to run twice.

**Planned** (land with their phases)

- `seed-baseline.sh` — regenerate a k6 latency baseline deliberately (P5)
- `render-manifests.sh` — render overlays for local inspection (P3)
- `eks-creds.sh` — assume the landing-zone role and write kubeconfig (P2)

**Contract**

- No secrets printed or persisted. Credentials live in env vars with the shortest viable lifetime.
- Every script supports `--dry-run` if it mutates anything.
