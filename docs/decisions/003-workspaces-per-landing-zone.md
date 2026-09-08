# ADR-003: Terraform workspaces per landing zone

**Status:** accepted
**Date:** 2026-09-07

## Context

Two environments (dev, prod) live in **separate AWS accounts** (ADR/plan:
separate landing zones). Options for modeling them: directory-per-env
(copied stacks), components, or one root with workspaces + tfvars.

## Decision

One root module; `terraform workspace` selects the landing zone; per-env
inputs in `envs/{dev,prod}.tfvars`; the provider assumes a per-LZ role.
State keys are per-workspace (`init -backend-config="key=dev/..."`).

## Consequences

- Environment drift is impossible by construction: there is no second copy
  of the stack to diverge — only a second set of values.
- Adding an environment = one tfvars file + one workspace + one role ARN.
- Workspace-keyed state requires the documented init invocation; stated in
  the infra README rather than left as tribal knowledge.
