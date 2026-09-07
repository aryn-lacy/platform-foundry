# bootstrap/ — remote state foundations

The one manual step in an otherwise automated estate, made explicit instead of hidden.

**What it creates** (run once per organization, outside the workload stack):

- S3 bucket for Terraform state (versioned, encrypted, public-access-blocked, SSL-only policy)
- DynamoDB table for state locking

**Why manual:** the state backend cannot be created by the configuration whose
state it will hold. Chicken, egg, one-time.

**Usage**

```bash
cd infra/bootstrap
terraform init
terraform plan
terraform apply
```

Then reference the outputs in `infra/backend.tf`.

Module body lands with Phase 2 (`#2`).
