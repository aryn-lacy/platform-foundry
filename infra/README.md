# infra/ — the AWS estate

Modular Terraform. One root, workspaces selecting the landing zone (`dev`, `prod`).

**Layout**

- `main.tf` — provider/locals glue only; every domain has its own file
- `vpc.tf` · `eks.tf` · `rds-postgres.tf` · `secrets.tf` · `ecr.tf` · `argocd.tf` — domain-grouped module instantiations
- `variables.tf` / `outputs.tf` / `versions.tf` (pinned providers) / `backend.tf` (state config, documented)
- `modules/` — `network`, `eks`, `database`, `secrets`, `ecr`, `argocd` (resource bodies live here, not at root)
- `envs/dev.tfvars`, `envs/prod.tfvars` — per-landing-zone role ARN + sizing
- `bootstrap/` — state bucket + lock table; the one documented manual step

**Contract**

- Root files instantiate; modules contain. A root file that grows a resource body is a bug.
- No secrets in tfvars — values are references; materialization happens in Secrets Manager.
- `terraform validate` must pass for both workspaces before merge (CI enforces).
