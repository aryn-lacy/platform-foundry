# platform-foundry

A production-grade continuous delivery platform on AWS — defined entirely as code.

Terraform provisions the estate (VPC, EKS Auto Mode, RDS PostgreSQL, Secrets Manager, ECR).
Argo CD delivers workloads via GitOps. Argo Rollouts canaries every release with
metric-gated aborts. CI builds, scans, and policy-checks before anything ships.
k6 fails the build on performance regressions against versioned baselines.

The platform is the product. The application it deploys is a placeholder payload —
a RealWorld ("Conduit") full-stack app (Spring Boot API, Keycloak identity, React
frontend) chosen to exercise every part of the delivery system realistically.

## Justifications of technologies used
- **ArgoCD** -- Industry standard tooling, I find dev teams have an easier time understanding and using argocd web based ui and pull based application approach for deployment
- **k6** -- small footprint, made it easy to work with in ci/cd pipeline instead of the heavier lift of the other options
- **OpenTofu** -- Better open source support for self hosted ci/cd pipelines along with encrypted state. Infra code is agnostic and terraform can be dropped in with no changes.
- **Checkov** -- Excellent static code analysis tool for working with infra code and includes many many classes of misconfigurations and insecure configurations as failures. Great for ensuring secure terraform code
- **tfsec/trivy** -- Checks for misconfigurations however we are using this tool for the Rego policies to ensure proper image creation and use in environment. 
- **Github Actions** -- CI/CD environment, choice of convience. This could easily be implemented in any modern CI system like Gitlab CI or Jenkins Pipelines.
- **EKS Auto Mode** -- Used to automatically scale the cluster. Reduces amount of time need for ops to work on clusters. Good trade for small shops where ops labor is at a premium. Can easily be swapped for karpenter if need. 
- **Kustomizer** -- Smaller lift then Helm Charts for adding the services to the eks cluster. Helm would be the choice for a complex setup requiring external packaging. 
- **Otel Collector** -- Industry standard tool for collecting and emiting otel metrics and logs for systems like Prometheus and the LGTM stack. 
- **Handspun Terraform Modules** -- Allows for easy reuse and quick updating of the resources when the pattern is called for again. Community modules typically result in churn for ops teams as the modules get updated and break former established use patterns.
- **Terraform Workspaces** -- Infra code should be the same between environments making workspaces a great and viable way to switch between the different environments. In practice the relatively small footprint of this infra code would still allow for the use of workspaces even if infrastructure is vastly different between dev and prod environments. 
- **Backend** -- Represented by [marcusmonteirodesouza/realworld-backend-spring-boot-java-keycloak-postgresql](https://github.com/marcusmonteirodesouza/realworld-backend-spring-boot-java-keycloak-postgresql). I believe that this is a good representation of what a production grade backend would look like and matches architechture I have deployed.
- **Frontend** -- Represented by [yurisldk/realworld-react-fsd](https://github.com/yurisldk/realworld-react-fsd). A well developed and actively kept frontend that maintains the realworld spec. This matches many of the web applications I have deployed. 
- **Container Promotion** -- Handled via tag promotion and enforced via ci/cd pipeline. A Dev Image with the same tag must exist before a prod image can be promoted. Ensures we know what is getting to prod and that the deployment packages match what we have in dev. 

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
