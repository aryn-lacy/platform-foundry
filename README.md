# platform-foundry

A production-grade continuous delivery platform on AWS — defined entirely as code.

Terraform provisions the estate (VPC, EKS Auto Mode, RDS PostgreSQL, Secrets Manager, ECR).
Argo CD delivers workloads via GitOps. Argo Rollouts canaries every release with
metric-gated aborts. CI builds, scans, and policy-checks before anything ships.
k6 fails the build on performance regressions against versioned baselines.

The platform is the product. The application it deploys is a placeholder payload —
a RealWorld ("Conduit") full-stack app (Spring Boot API, Keycloak identity, React
frontend) chosen to exercise every part of the delivery system realistically.

## What this repository demonstrates

- **Infrastructure as code** — modular Terraform, pinned providers, one code path
  per landing zone via workspaces (`dev`, `prod`)
- **Kubernetes operations** — EKS Auto Mode, AWS-managed add-ons, workload
  hardening (probes, PDBs, topology spread, security contexts, default-deny
  NetworkPolicies)
- **GitOps & progressive delivery** — app-of-apps, per-environment overlays,
  step-pause canaries with AnalysisTemplate guards, commit-as-deploy-record
- **Supply chain & policy** — Trivy image scanning, tfsec/Checkov on Terraform,
  Conftest/OPA on rendered manifests, all pre-merge
- **Performance engineering** — k6 load profiles with thresholds, latency
  baselines versioned in git, regressions fail the build

## Repository layout

```
apps/        placeholder payload — CI path-filters build on changes here
infra/       terraform — one root, workspaces per landing zone
k8s/         the manifests Argo CD delivers (base + dev/prod overlays)
argocd/      Argo CD's own configuration (app-of-apps, projects, sync policies)
policies/    policy-as-code — conftest/OPA rules enforced in CI
k6/          load profiles + committed performance baselines
.github/     workflows: build, scan, policy, perf, promotion
scripts/     helper contracts (baseline seeding, manifest rendering)
docs/        architecture, assumption register, ADRs, runbooks, diagrams
```

Each directory carries a README stating its contract — what belongs there and
what must not.

## Quickstart

```bash
git clone https://github.com/aryn-lacy/platform-foundry.git
cd platform-foundry
make help                      # every available target
make policy                    # local policy gate (12 rendered targets)
make policy-test               # prove the policy rules fire
make lint-workflows            # actionlint over CI workflows
```

# Provision (per landing zone):
```
cd infra
tofu init
tofu workspace select dev  # or: tofu workspace new dev
tofu plan -var-file=envs/dev.tfvars
```

Remote state bootstrap is the one documented manual step — see
[`infra/bootstrap/`](infra/bootstrap/).

## Environments

Two landing zones, one stack. `dev` auto-syncs; `prod` is promotion-gated —
a pull request that moves the image tag between overlays. The PR *is* the
audit record. See [`docs/architecture.md`](docs/architecture.md) for the full
model once published.

## Documentation

- [`docs/architecture.md`](docs/architecture.md) — the system, end to end
- [`docs/assumptions.md`](docs/assumptions.md) — what is assumed vs. built
- [`docs/decisions/`](docs/decisions/) — numbered ADRs
- [`docs/runbooks/`](docs/runbooks/) — restore, rollback

## License

[MIT](LICENSE)
