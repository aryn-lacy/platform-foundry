# P4: CI Workflows + Policy-as-Code Gates — Implementation Plan

> **For Hermes:** Execute task-by-task on branch `feat/p4-ci`. Docs are the spec (architecture.md §5, issue #4, policies/README.md contract). Whole-file authoring, no string surgery. PR = draft → code-reviewer kanban card (defaults only) → Aryn merges.

**Goal:** Issue #4 — the build/prove/scan/gate pipeline: 4 GitHub Actions workflows + Rego policy pack with fixtures, all actionlint-clean, no cluster credentials anywhere.

**Architecture:** CI renders and gates but never touches the cluster — deployment is the set-image commit Argo pulls. Policy gates run locally (Makefile) and in CI (same binaries) so `make test` ≡ CI green.

**Tech stack:** GitHub Actions, actionlint, conftest + OPA/Rego, tfsec + checkov, kustomize v5.4.3 (pinned, `~/.local/bin/kustomize`), OpenTofu via `opentofu/setup-action` (TOOLING LOCK — never hashicorp/setup-terraform), Maven (vendored RealWorld Spring Boot + Keycloak backend), trivy, docker/build-push-action.

---

## Design decisions needing Aryn's ratification BEFORE Task 6+

**Update 2026-09-08 21:58Z — ALL FOUR RESOLVED by Aryn post-recon:**

- **D1 — Placeholder payload shape → (d) VENDOR REALWORLD APPS — CORRECTED PAIRING 2026-09-08.** The final call (Aryn, Sep 7 session, msg 17749/17757): **`marcusmonteirodesouza/realworld-backend-spring-boot-java-keycloak-postgresql`** → `apps/backend/` + `yurisldk/realworld-react-fsd` → `apps/frontend/`. Backend is **Keycloak-native** (Spring Security OAuth2 against Keycloak, native Postgres) — this is the app the whole platform was designed around: keycloak namespace, ADR-008 identity RDS tier, realm `realworld-backend` client, backend NP egress to keycloak. The earlier survey's sivaprasadreddy pick was explicitly REJECTED by Aryn ("would not at all ever make it to production"). Posture notes: repo has NO LICENSE (Aryn accepted explicitly: "not concerned about the license issues" — portfolio use, credit upstream in per-app README); dormant since 2024-06 (fine — reviewers won't run it); **Maven, not Gradle** (mvnw + pom.xml — CI stages and Dockerfile are mvn-based); ships its own Dockerfile + docker-compose (we still author the layered multi-stage Dockerfile per plan lock, Maven flavor: deps → build → runtime).
- **D2 — ECR push gating → CONFIRMED cost-free posture: skip-with-message.** No AWS account, no spend, no applies — standing project constraint (memory: no real AWS spend). Push + set-image jobs run only when `secrets.AWS_ACCOUNT_ID` exists; else explicit "ECR push skipped — no registry credentials (portfolio posture)" step summary. Workflows are real and runnable, the push machinery simply waits for credentials that deliberately don't exist. Also gates `tag-promotion.yml`'s tag-existence check to repo files only (dev overlay file on PR head — no API calls).
- **D3 — tfsec naming → keep `tfsec` binary + `checkov` as two steps**, matching issue text literally (tfsec folds into trivy upstream; binary still ships). No change.
- **D4 — Makefile drift fix rides in this PR** (Task 2) since `make policy` is the vendoring-agnostic local half of the same gate. No change.

## Current state / assumptions

- Repo at `~/workspace/platform-foundry`, main = P3 merged (PR #11, 21:55Z). `.github/workflows/` has only `.gitkeep`. `policies/` has README only.
- Makefile `policy:` target: loops `backend frontend keycloak` only (analysis, bootstrap missing) and uses `kubectl kustomize` — drift vs P3 reality and the pinned binary.
- conftest + actionlint not yet installed on cosmos (kustomize/tofu/gh are). Linuxbrew IS present; `eget` available.
- Repo runs on gh `aryn-lacy` (public portfolio account) — already active.

---

## Task 1: Tool acquisition + Makefile tool targets

**Files:** Modify `Makefile` (add `tools` target).

- Install: `brew install conftest actionlint` (fallback: `eget aquasecurity/tfsec`-style direct downloads to `~/.local/bin`).
- Add `tools:` target documenting both installs; `make tools` idempotent.
- Verify: `conftest --version`, `actionlint --version` both exit 0.

## Task 2: Fix the policy gate drift (Makefile)

**Files:** Modify `Makefile` (`policy:` target).

- Loop over **all five** apps × dev/prod: `backend frontend keycloak analysis bootstrap`.
- Use `kustomize build` (the pinned binary) not `kubectl kustomize`; also render `argocd/apps/dev` + `argocd/apps/prod` — the full 12-target matrix that every validation round used.
- `set -eu` semantics: first failure stops the loop with the offending overlay named.
- Verify: `make policy` → 12 targets rendered through conftest (will fail until Task 3 rules exist — expected failure mode is "no policies found" = rules missing, NOT a render failure). Confirm render coverage by temporarily counting rendered docs.

## Task 3: Rego policy pack + fixtures

**Files:** Create `policies/k8s/no-latest.rego`, `policies/k8s/resource-limits.rego`, `policies/k8s/no-privileged.rego`, `policies/k8s/restricted-egress.rego`, fixtures under `policies/k8s/fixtures/{pass,fail}/` (YAML docs per rule: pass+fail), `Makefile` (`policy-test:` target), update `policies/README.md` (drop "land with Phase 4" TBD).

- **Rule shape gotcha (the one that matters):** workloads are Deployment, **Rollout** (Argo Rollouts CRD), and Job. Rules must walk `spec.template.spec.containers` on any object whose kind is in that set — a Deployment-only rule silently passes the whole backend/frontend fleet. Fixtures MUST include a Rollout and the bootstrap Job.
- `no-latest`: deny `image` ending `:latest` or tagless.
- `resource-limits`: every container in every workload kind has `resources.limits` (cpu+memory).
- `no-privileged`: deny `privileged: true`, `hostNetwork: true`, `hostPath` volumes, unset seccomp? (No — scope to issue text: privileged/hostNetwork/hostPath.)
- `restricted-egress`: every workload Namespace's NetworkPolicy posture = default-deny ingress+egress present; egress only to declared destinations. Simplest enforceable form: deny workloads lacking an NP in the same rendered bundle OR deny NPs with `egress: - {}` (allow-all). Author to the issue text's intent, document interpretation in the .rego header comment.
- `policy-test:` runs conftest against fixtures: **fail-fixtures must fail, pass-fixtures must pass** — a rule that can't fail gets deleted ("a rule without a test fixture is a wish").
- Verify: `make policy-test` → all four rules fire both ways; `make policy` → live estate passes clean.

## Task 4: `policy.yml` — the infra+manifests gate

**Files:** Create `.github/workflows/policy.yml`.

- Triggers: PR + push to main touching `infra/**`, `k8s/**`, `argocd/**`, `policies/**`.
- Jobs:
  1. `terraform`: checkout → `opentofu/setup-action` (TOOLING LOCK) → `tofu fmt -check` → `tofu init -backend=false` → `tofu validate` (root; env dirs as matrix if init needs vars — validate only, NO plan: no credentials by design).
  2. `iac-scan`: tfsec on `infra/` (fail on HIGH+) + checkov on `infra/` (**HARD-FAIL** per Aryn 2026-09-08: "run tfsec/checkov in the pipeline so we can have an example of it failing" — no soft-fail baseline; findings get fixed, not waivered). Plus a **gate-demo branch**: after the estate is clean, push `demo/policy-gate-failure` containing one deliberate violation (e.g. an unencrypted EBS or a `:latest` tag in a scratch overlay) → red run stays in Actions history as the visible example → link it in the PR body as evidence. The demo branch is never merged.
  3. `manifests`: kustomize v5.4.3 → render all 12 targets → conftest `-p policies/k8s`.
- Verify: `actionlint .github/workflows/policy.yml` clean; green first run on the PR.

## Task 5: `tag-promotion.yml` — the promotion gate's enforcement

**Files:** Create `.github/workflows/tag-promotion.yml`.

- Trigger: PR touching `k8s/*/overlays/prod/**`.
- Job validates the PR is a legal promotion: (1) diff moves an image tag in prod overlays only — no other shape changes; (2) the new tag exists in the dev overlay (same workload) — read both files from the PR head; (3) fail with a structured message naming the violated rule. Small composite action or inline bash + yq.
- Negative case is the point: a prod PR introducing an unseen-anywhere tag goes red. Test by pushing a throwaway branch during dev (locally via `act` optional; at minimum yq logic tested standalone).
- Verify: actionlint clean; logic dry-run against P3's current overlays (dev tag == prod placeholder → validator must treat placeholder-vs-placeholder as "no promotion in flight, pass").

## Task 6: Vendor the RealWorld apps (per D1)

**Files:** Create `apps/backend/**` (vendored from marcusmonteirodesouza/realworld-backend-spring-boot-java-keycloak-postgresql), `apps/frontend/**` (vendored from yurisldk/realworld-react-fsd), `apps/README.md`.

- Method: `git clone --depth 1` → copy source tree into `apps/{backend,frontend}/` **without `.git`**, **without their CI dotfiles** (`.github/` if any — strip), **without test artifacts/builds**. Backend has NO LICENSE upstream — we do NOT add one on their behalf (not our call); credit the upstream repo by URL in `apps/backend/README.md` with a note that it's vendored unmodified for portfolio/demo purposes. Frontend keeps its MIT LICENSE file.
- Backend keeps its own build files (**Maven** wrapper `mvnw` + `pom.xml`), Keycloak OAuth2 config, and test suite. We author the layered Dockerfile at `apps/backend/Dockerfile` per the plan lock (deps → build → runtime stages, Maven flavor) — upstream's own Dockerfile is single-stage; ours is the cache-correct layered one.
- Frontend: keep its Dockerfile/nginx.conf as-shipped (already multi-stage with `API_URL` build arg); author nothing.
- Volume: backend ~100–200 files (incl. docs/images — strip screenshots/diagrams, keep `src/`, `pom.xml`, `mvnw`, `.mvn/`, README), frontend ~50–100. Accept the diff size — it's the payload the platform demonstrably ships.
- Verify: `docker build` both locally on cosmos; `apps/backend` Maven compile/test runs in CI (Task 7), not locally.
- Branding lock: no mention of commissioning context anywhere; per-app READMEs credit upstream only.

## Task 7: `backend-ci.yml`

**Files:** Create `.github/workflows/backend-ci.yml`.

- Path filter: `apps/backend/**`, `k8s/backend/**`.
- Jobs: `lint-unit` (setup-java + maven cache, `./mvnw test`) → `integration` (testcontainers: keycloak + postgres — mirrors the app's own docker-compose services; ubuntu runner docker available; needs lint-unit) → `build-scan-push` (docker/build-push-action layer-cache via GHA cache; trivy action `--exit-code 1 --severity CRITICAL`; ECR push **gated on `secrets.AWS_ACCOUNT_ID`** per D2) → `set-image` (needs push; `kustomize edit set image backend=<ecr-uri>:sha-${{github.sha}}` on `k8s/backend/overlays/dev`; commit to main with `[skip ci]` using GITHUB_TOKEN contents-write; same gating).
- Verify: actionlint clean; first live run green with ECR skip message visible.

## Task 8: `frontend-ci.yml`

**Files:** Create `.github/workflows/frontend-ci.yml`.

- Mirror of Task 7 minus maven/testcontainers; build-arg `API_URL` injected from vars; trivy; gated ECR + set-image on `k8s/frontend/overlays/dev`.
- Verify: actionlint clean; green run.

## Task 9: Docs + README truth pass

**Files:** Modify `docs/architecture.md` §5 (drop "workflows land with Phase 4" future tense), `policies/README.md` (already Task 3), `README.md` quickstart (add `make policy policy-test lint-workflows` to the local-gate section), `Makefile` (`test: policy policy-test lint-workflows`).

- Grep sweep: `grep -rn "Phase 4\|land with" docs/ README.md` — no future-tense leftovers.
- Verify: docs claim == CI reality (workflow names, gate order).

## Task 10: DoD verification + PR

- `make lint-workflows` (actionlint over all four workflows) → clean.
- `make policy && make policy-test` → estate green, fixtures prove rules fire.
- `tofu fmt -check` + `validate` ×3 (root/dev/prod) — unchanged infra must stay green.
- Branch `feat/p4-ci`, PR body: claims → evidence → verification (P3 format), `Closes #4`, draft → push → code-reviewer kanban card (defaults only, no --model) → Matrix-notify subscribe → **Aryn merges**.

---

## Risks / tradeoffs

- **Rollout-kind Rego blindness** — handled in Task 3 fixtures; it's the likeliest reviewer finding if missed.
- **First checkov/tfsec run may flag P2 infra** — pre-scan locally in Task 4 before pushing; either fix findings or document soft-fail baseline decision in the PR (Aryn's call).
- **GHA cache + Docker layer caching on fork-PRs** — cache scope notes in workflow comments.
- **`[skip ci]` commit loop** — set-image commit must not re-trigger backend-ci (path filter on apps/ only, plus the marker; double protection).
- **Scope discipline** — no k6 (P5), no Digger/apply (roadmap item 4), no cluster creds ever.
