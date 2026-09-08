# Runbook: Rollout rollback

**Scope:** a bad release detected during canary or after promotion.

## During canary (Argo Rollouts)

The AnalysisTemplate guard aborts automatically on threshold breach —
traffic returns to the stable ReplicaSet. If the analysis dependency
(platform Prometheus) is unavailable, abort manually:

```bash
kubectl argo rollouts abort <rollout> -n <namespace>
kubectl argo rollouts undo  <rollout> -n <namespace>
```

## After promotion (GitOps)

The deployed state **is** the git commit. Rollback = revert:

1. Revert the promotion/set-image commit on main (`git revert <sha>`)
2. Argo CD syncs the previous image tag (dev auto-syncs; prod: approve the
   sync or let the gated sync policy apply it)
3. Verify: `kubectl argo rollouts get rollout <name> --watch`

## Database caveat

Schema is application-managed in this reference (JPA `ddl-auto`; no
Flyway). A rollback after a schema-changing release may need
`ddl-auto` compatibility — expand-only changes roll back cleanly;
contract changes need a forward fix. The production posture — Flyway
pinned, `ddl-auto=validate`, migrations as a pre-rollout pipeline gate —
is the recommendation carried in the architecture doc's roadmap.

## Escalation path

1. Abort rollout (above)
2. If data-tier involvement suspected: `db-restore.md` runbook
3. Post-incident: ADR entry if the failure mode reveals a decision gap
