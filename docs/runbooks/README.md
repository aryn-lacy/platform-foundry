# runbooks/ — if it isn't written, it isn't a procedure

- [`db-restore.md`](db-restore.md) — per-tier RDS restore from automated
  backup / point-in-time (ADR-008 tier isolation; break-glass + secret
  version-history caveats)
- [`rollback.md`](rollback.md) — canary abort and GitOps promotion
  rollback (git revert); JPA schema caveat stated
