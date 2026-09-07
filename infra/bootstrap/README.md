# bootstrap/ — remote state foundations

The one manual step in an otherwise automated estate, made explicit instead of hidden.

**What it creates** (run once per organization, outside the workload stack):

- S3 bucket for Terraform state (versioned, encrypted, public-access-blocked, SSL-only policy)

**Locking:** S3-native (`use_lockfile = true` in the root backend, OpenTofu ≥ 1.10) — conditional writes against the state object itself. No DynamoDB lock table exists. This is the modern replacement for the legacy `dynamodb_table` approach: one fewer resource, one fewer dependency, same guarantee (second concurrent apply fails to acquire the lock).

**Why manual:** the state backend cannot be created by the configuration whose
state it will hold. Chicken, egg, one-time.

**Usage**

```bash
cd infra/bootstrap
tofu init
tofu plan
tofu apply
```

Then reference the outputs in `infra/backend.tf`.

Module body lands with Phase 2 (`#2`).
