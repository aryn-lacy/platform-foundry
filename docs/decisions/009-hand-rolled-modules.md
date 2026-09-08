# ADR-009: Hand-rolled modules over community sources

**Status:** accepted
**Date:** 2026-09-08

## Context

Every infrastructure domain (network, EKS, database, secrets, ECR, Argo CD
bootstrap) could be consumed from community module registries
(terraform-aws-modules et al.) instead of authored.

## Decision

Author every module in-repo. No community module sources.

## Rationale

- **Full surface knowledge.** A hand-rolled module is code read line by
  line; its variables, defaults, and upgrade behavior are known, not
  researched. Community modules ask you to internalize someone else's
  abstraction surface before safely changing a single line.
- **No upstream churn tax.** Community modules change underneath you —
  version bumps alter defaults, refactor interfaces, and occasionally get
  clever in ways that break in production-interesting ways. Time spent
  debugging the module exceeds time saved not writing the resource blocks.
- **The cost asymmetry flipped.** With LLM-assisted development, the
  marginal cost of authoring a small, well-structured module is far below
  its historical cost. Writing is cheap; debugging foreign cleverness is
  not.

## Consequences

- Module discipline is the load-bearing constraint: one concern per
  module, interface-stable, root files consume outputs only. When a module
  grows a second concern, it splits (`infra/modules/README.md` contract).
- For teams without that discipline — or with heavy multi-account
  conventions — community modules remain a defensible choice; this ADR
  records a cost/benefit position, not an industry verdict.
