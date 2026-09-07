# policies/ — policy as code

Executable guardrails, enforced in CI before anything merges or deploys.

**Layout** (rules land with Phase 4, `#4`)

- `k8s/` — Rego (conftest) rules for rendered manifests
- `terraform/` — reserved for tfsec/Checkov custom checks (flags live in CI)

**Rules enforced** (each ships with passing + failing fixtures)

- no `:latest` image tags — immutable digests or versioned tags only
- resource limits required on every container
- no privileged containers; no hostNetwork/hostPath
- egress restricted to declared destinations

**Contract**

- A rule without a test fixture is not a rule, it is a wish.
