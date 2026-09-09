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

# Dedicated CMK per tier for Performance Insights encryption (tfsec
# AVD-AWS-0078): app and identity tiers keep separate key material.
# Explicit key policy (checkov CKV2_AWS_64): account-root IAM control.
data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

resource "aws_kms_key_policy" "pi" {
  for_each = local.instances

  key_id = aws_kms_key.pi[each.key].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "Enable IAM User Permissions"
        Effect    = "Allow"
        Principal = { AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        # RDS Performance Insights generates data keys under the caller's
        # identity — without this grant PI enablement fails (review C1).
        Sid       = "AllowRDSServiceUse"
        Effect    = "Allow"
        Principal = { Service = "rds.${data.aws_region.current.name}.amazonaws.com" }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey",
        ]
        Resource = "*"
        Condition = {
          StringEquals = { "kms:ViaService" = "rds.${data.aws_region.current.name}.amazonaws.com" }
        }
      },
    ]
  })
}

data "aws_region" "current" {}

resource "aws_kms_key" "pi" {
  for_each = local.instances

  description             = "${var.project_name}-${terraform.workspace}-${each.key} performance insights"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = merge(var.common_tags, { Tier = each.key })
}

# RDS Enhanced Monitoring service role, one per tier instance (checkov
# CKV_AWS_118 wiring).
data "aws_iam_policy_document" "rds_monitoring_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rds_monitoring" {
  for_each           = local.instances
  name               = "${var.project_name}-${terraform.workspace}-${each.key}-rds-monitoring"
  assume_role_policy = data.aws_iam_policy_document.rds_monitoring_assume.json
  tags               = merge(var.common_tags, { Tier = each.key })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  for_each   = local.instances
  role       = aws_iam_role.rds_monitoring[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
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

  # The tier databases' only ingress: PostgreSQL from the declared CIDRs
  # (checkov CKV_AWS_23 — resource + rule both described).
  description = "PostgreSQL ingress for the tier databases"

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
  # checkov:skip=CKV2_AWS_30: Query logging requires the pgaudit shared library parameter group + instance reboot cycle; logs flow via enabled_cloudwatch_logs_exports postgresql — adding pgaudit is roadmap, not an omission
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
  # PI data encrypted with a dedicated per-tier CMK (tfsec AVD-AWS-0078).
  performance_insights_kms_key_id = aws_kms_key.pi[each.key].arn

  # Minor engine patches applied automatically in their window (checkov
  # CKV_AWS_226); major upgrades stay deliberate (maintenance_minor only).
  auto_minor_version_upgrade = true

  # IAM DB authentication available for tooling (checkov CKV_AWS_161) —
  # app+keycloak pods keep secret-based creds via CSI; this adds a
  # token-based path without removing the existing one.
  iam_database_authentication_enabled = true

  # Enhanced Monitoring at 60s granularity (checkov CKV_AWS_118), 30d
  # retention — pairs with CloudWatch logs + PI for the debugging story.
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring[each.key].arn

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
