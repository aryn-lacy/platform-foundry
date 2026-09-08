# Runbook: RDS restore (per instance, per tier)

**Scope:** either RDS instance (`-app`, `-keycloak`). Tiers are isolated —
restoring one does not touch the other (ADR-008).

## Automated backups

- Daily automated backups, retention per env (dev 7d, prod 30d)
- Backup window 03:00–04:00 UTC; maintenance window separate (Sun 04:30)
- Point-in-time recovery available between snapshots

## Restore procedure

1. **Identify the target time/snapshot**
   ```bash
   aws rds describe-db-snapshots --db-instance-identifier platform-foundry-<env>-<tier>
   ```

2. **Restore to a new instance** (never overwrite the primary):
   ```bash
   aws rds restore-db-instance-to-point-in-time \
     --source-db-instance-identifier platform-foundry-<env>-<tier> \
     --target-db-instance-identifier platform-foundry-<env>-<tier>-restore \
     --restore-time 2026-09-08T02:30:00Z \
     --multi-az --db-subnet-group-name platform-foundry-<env>
   ```

3. **Validate** the restored instance: connect with the break-glass
   credential (`db-master-<tier>` secret), check row counts / recent rows.

4. **Cut over**: update the connection endpoint where consumers read it
   (Secrets Manager app-db / keycloak-db entries), then swap identifiers
   or update the Service endpoints. Pods pick up new mounts on restart.

5. **Import the restored instance into Terraform state** if it replaces
   the original (rename dance: import under the original address).

## Failure modes

- Restore runs in the same subnets/SG — no connectivity surprises.
- The restored instance has the **original master password** (from backup
  time); if rotation has occurred since, use the pre-rotation break-glass
  value from the secret's version history (`aws secretsmanager
  list-secret-version-ids`).
