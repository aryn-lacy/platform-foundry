# policies/ — policy as code

Executable guardrails, enforced in CI before anything merges or deploys.
**Landed (Phase 4, issue #4).**

## Layout

- `k8s/` — Rego (conftest) rules for rendered manifests
- `k8s/fixtures/` — pass + fail fixtures; every rule must fire on its fail
  fixture and stay silent on its pass fixture (`make policy-test`)
- `terraform/` — reserved for custom checks (tfsec/checkov flags live in CI)

## Rules enforced

| Rule | File | Checks |
|---|---|---|
| no-`:latest` | `no-latest.rego` | every container of Deployment/Rollout/Job (incl. initContainers) uses a pinned tag, not `:latest` |
| resource limits | `resource-limits.rego` | every container sets `resources.limits.cpu` AND `resources.limits.memory` |
| no privileged | `no-privileged.rego` | no `privileged: true`, no `hostNetwork`, no `hostPath` volumes |
| restricted egress | `restricted-egress.rego` | every Deployment/Rollout is selected by a NetworkPolicy (workloadRef Rollouts resolve via their referenced Deployment); no allow-all (`egress: - {}`) rules |

Scope note: workload kinds are **Deployment, Rollout, AND Job** — the app
fleet deploys as Argo Rollouts; a Deployment-only rule would silently pass
it. Both Rollout shapes (inline template and workloadRef) are exercised in
the fixtures.

## Commands

- `make policy` — render all 12 kustomize targets, conftest each
- `make policy-test` — prove the rules fire (fail fixtures) and don't
  false-positive (pass fixtures)
- CI: `.github/workflows/policy.yml` runs the same gate plus tfsec/checkov
  on `infra/`

## Contract

- A rule without a test fixture is not a rule, it is a wish.
