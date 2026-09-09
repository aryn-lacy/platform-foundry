SHELL := /bin/sh

# Pinned local tools (override with `make KUSTOMIZE=...` if needed)
KUSTOMIZE ?= $(HOME)/.local/bin/kustomize
CONFTEST  ?= $(HOME)/.local/bin/conftest
ACTIONLINT ?= $(HOME)/.local/bin/actionlint

# Every kustomize target that must build: 5 workloads x dev/prod + argocd apps
KUST_TARGETS := \
	k8s/backend/overlays/dev \
	k8s/backend/overlays/prod \
	k8s/frontend/overlays/dev \
	k8s/frontend/overlays/prod \
	k8s/keycloak/overlays/dev \
	k8s/keycloak/overlays/prod \
	k8s/analysis/overlays/dev \
	k8s/analysis/overlays/prod \
	k8s/bootstrap/overlays/dev \
	k8s/bootstrap/overlays/prod \
	argocd/apps/dev \
	argocd/apps/prod

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)
CONFTEST_ASSET := $(UNAME_S)_$(if $(filter arm64 aarch64,$(UNAME_M)),arm64,x86_64).tar.gz

.PHONY: tools
tools: ## Install pinned local tooling (kustomize, conftest, actionlint via eget)
	$(HOME)/.local/bin/eget kubernetes-sigs/kustomize --to=$(HOME)/.local/bin
	$(HOME)/.local/bin/eget open-policy-agent/conftest --asset='$(CONFTEST_ASSET)' --to=$(HOME)/.local/bin
	$(HOME)/.local/bin/eget rhysd/actionlint --to=$(HOME)/.local/bin

.PHONY: fmt
fmt: ## Format opentofu (tofu)
	cd infra && tofu fmt -recursive

.PHONY: validate
validate: ## Validate opentofu for both environments
	cd infra && tofu init -backend=false && tofu validate

.PHONY: kustomize
kustomize: ## Render all 12 kustomize targets (5 workloads x 2 envs + argocd apps)
	@set -eu; \
	for t in $(KUST_TARGETS); do \
		echo "== $$t =="; \
		$(KUSTOMIZE) build "$$t" >/dev/null || { echo "RENDER FAILED: $$t"; exit 1; }; \
		echo "  ok"; \
	done; \
	echo "all 12 targets render"

.PHONY: policy
policy: ## Run conftest against all rendered manifests (12 targets, combined docs)
	@set -eu; \
	for t in $(KUST_TARGETS); do \
		echo "== policy: $$t =="; \
		$(KUSTOMIZE) build "$$t" | $(CONFTEST) test --combine -p policies/k8s - || { echo "POLICY FAILED: $$t"; exit 1; }; \
	done; \
	echo "policy gate green (12 targets)"

.PHONY: policy-test
policy-test: ## Prove each policy rule fires: fail-fixtures FAIL, pass-fixtures PASS
	@set -eu; \
	echo "== fail fixtures (must FAIL) =="; \
	find policies/k8s/fixtures/fail -name '*.yaml' | while read -r f; do \
		if $(CONFTEST) test --combine -p policies/k8s "$$f" >/dev/null 2>&1; then \
			echo "RULE GAP: $$f passed but must fail"; exit 1; \
		else \
			echo "  fires: $$f"; \
		fi; \
	done; \
	echo "== pass fixtures (must PASS) =="; \
	find policies/k8s/fixtures/pass -name '*.yaml' | while read -r f; do \
		$(CONFTEST) test --combine -p policies/k8s "$$f" >/dev/null 2>&1 || { echo "FALSE POSITIVE: $$f"; exit 1; }; \
		echo "  clean: $$f"; \
	done; \
	echo "all fixtures prove their rules"

.PHONY: test
test: policy policy-test lint-workflows ## Full local gate (policy + rule fixtures + workflow lint)

.PHONY: lint-workflows
lint-workflows: ## Lint github actions workflows (actionlint)
	$(ACTIONLINT)
