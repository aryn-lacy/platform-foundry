.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

.PHONY: fmt
fmt: ## Format terraform
	cd infra && terraform fmt -recursive

.PHONY: validate
validate: ## Validate terraform for both workspaces
	cd infra && terraform init -backend=false && terraform validate

.PHONY: kustomize
kustomize: ## Render all k8s overlays to stdout summary
	@for env in dev prod; do \
		for app in backend frontend keycloak; do \
			echo "== $$env/$$app =="; \
			kubectl kustomize k8s/$$app/overlays/$$env >/dev/null && echo "  ok"; \
		done; \
	done

.PHONY: policy
policy: ## Run conftest against rendered manifests
	@for env in dev prod; do \
		for app in backend frontend keycloak; do \
			kubectl kustomize k8s/$$app/overlays/$$env | conftest test -p policies/k8s - || exit 1; \
		done; \
	done

.PHONY: test
test: policy ## Full local gate (extends as phases land)

.PHONY: lint-workflows
lint-workflows: ## Lint github actions workflows (requires actionlint)
	actionlint
