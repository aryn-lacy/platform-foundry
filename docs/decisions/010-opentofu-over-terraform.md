# ADR-010: OpenTofu over Terraform

**Status:** accepted
**Date:** 2026-09-08

## Context

The configuration language is HCL either way; the choice is the runner.

## Decision

OpenTofu (`tofu`), pinned `>= 1.10` (S3-native `use_lockfile` state
locking).

## Rationale

- **Convenience:** the authoring environment and the author's personal IaC
  standardize on the latest OpenTofu; one toolchain across projects.
- **OSS CI ecosystem fit:** open-source delivery tooling — Digger, and
  OpenTaco-class state runners — integrates more smoothly with OpenTofu in
  CI pipelines.
- **Drop-in compatibility:** the Terraform binary replaces `tofu` with
  **zero code changes** — the HCL is tool-identical; only the runner
  differs. A landing zone mandating Terraform would not require a port.
- **No enterprise pricing:** the closest Terraform equivalents to the
  state/workspace workflow used here sit behind enterprise pricing;
  personal projects have no reason to pay it when a Linux-Foundation-
  governed open implementation exists.

## Consequences

- CI uses the OpenTofu setup action (`opentofu/setup-opentofu`), not hashicorp's.
- The S3-native locking feature is OpenTofu-1.10+; the DynamoDB lock-table
  path remains available if a Terraform runner is ever mandated (documented
  in `infra/bootstrap/README.md`).
