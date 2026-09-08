# Two RDS PostgreSQL instances — identity tier isolated from application
# tier (ADR-008). Keycloak's storage shares nothing with the application's:
# separate instance, separate compute/storage, separate backup estate,
# independent maintenance and restore granularity.
#
# Alternative considered and rejected for this reference posture: a single
# shared instance with two logical databases (cheaper; couples IdP and app
# blast radius). That remains the choice for genuinely cost-constrained
# deployments — the trade is documented, not hidden.
#
# Credential flow (per instance, full picture):
# - random_password.master[tier] IS that instance's master credential: it
#   sets the RDS password at creation and is materialized exactly once by
#   modules/secrets as the break-glass db-master-<tier> secret.
# - Each instance creates its own database (db_name) and master user. The
#   least-privilege service ROLES (realworld_app on app, keycloak on
#   keycloak) are created by the Phase-3 bootstrap Job, which connects as
#   each master via CSI-mounted break-glass secrets and creates the role
#   with its already-staged password.
# - Workload pods then connect with their own roles; masters return to
#   break-glass duty.

locals {
  instances = {
    app = {
      db_name        = "realworld_app"
      instance_class = var.instance_classes["app"]
    }
    keycloak = {
      db_name        = "keycloak"
      instance_class = var.instance_classes["keycloak"]
    }
  }
}

resource "random_password" "master" {
  for_each = local.instances

  length  = 24
  special = false
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.project_name}-${terraform.workspace}"
  subnet_ids = var.subnet_ids
  tags       = var.common_tags
}

# One security group shared by both instances: the network rule is identical
# (5432 from the VPC). Tier isolation is at the instance level — a shared SG
# does not couple the tiers any more than shared subnets do.
resource "aws_security_group" "db" {
  name_prefix = "${var.project_name}-${terraform.workspace}-db-"
  vpc_id      = var.vpc_id

  ingress {
    description = "PostgreSQL from the cluster and VPC only"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  tags = var.common_tags
}

resource "aws_db_instance" "this" {
  for_each = local.instances

  identifier     = "${var.project_name}-${terraform.workspace}-${each.key}"
  engine         = "postgres"
  engine_version = "16.4"
  instance_class = each.value.instance_class

  db_name  = each.value.db_name
  username = "foundry_admin"
  password = random_password.master[each.key].result

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]

  allocated_storage     = 50
  max_allocated_storage = 200

  multi_az                  = true
  storage_encrypted         = true
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.project_name}-${terraform.workspace}-${each.key}-final"

  backup_retention_period = var.backup_retention_days # daily automated backups (requirement)
  backup_window           = var.backup_window
  maintenance_window      = var.maintenance_window
  copy_tags_to_snapshot   = true

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  performance_insights_enabled    = true

  tags = merge(var.common_tags, { Tier = each.key })

  lifecycle {
    # Set once by random_password at creation; ignoring drift means a
    # re-generated random never forces a master-password rotation. The
    # break-glass COPY lives in Secrets Manager (modules/secrets) — that is
    # materialization, not rotation.
    ignore_changes = [password]
  }
}

# NOTE on deferred entities (the Phase-3 bootstrap Job contract):
# Each instance provisions its own database and the master user. The
# bootstrap Job creates exactly TWO roles, one per instance:
#   1. `realworld_app` role on the app instance (password: app-db secret)
#   2. `keycloak` role on the keycloak instance (password: keycloak-db secret)
# Until that Job runs, the service-role credentials are staged but not yet
# usable — by design, not by accident. This comment is the contract;
# removing it requires updating docs/architecture.md.
