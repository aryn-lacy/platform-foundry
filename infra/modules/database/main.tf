# One instance, two databases (ADR-007-adjacent cost decision, documented in
# docs/decisions/): the RealWorld app database and Keycloak's database share
# a Multi-AZ PostgreSQL instance. Credentials are NOT set here — they are
# generated and stored by modules/secrets and injected via the Secrets Store
# CSI driver at pod start (see k8s/*/base).

resource "random_password" "master" {
  length  = 24
  special = false
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.project_name}-${terraform.workspace}"
  subnet_ids = var.subnet_ids
  tags       = var.common_tags
}

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

resource "aws_db_instance" "postgres" {
  identifier     = "${var.project_name}-${terraform.workspace}"
  engine         = "postgres"
  engine_version = "16.4"
  instance_class = var.instance_class

  db_name  = "realworld_app"
  username = "foundry_admin"
  password = random_password.master.result

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]

  allocated_storage     = 50
  max_allocated_storage = 200

  multi_az                  = true
  storage_encrypted         = true
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.project_name}-${terraform.workspace}-final"

  backup_retention_period = var.backup_retention_days # daily automated backups (requirement)
  backup_window           = var.backup_window
  maintenance_window      = var.maintenance_window
  copy_tags_to_snapshot   = true

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  performance_insights_enabled    = true

  tags = var.common_tags

  lifecycle {
    ignore_changes = [password] # rotated by modules/secrets / Secrets Manager, not by plan diffs
  }
}

# Second database on the shared instance: keycloak.
# NOTE on deferred database entities: PostgreSQL RDS creates ONE database
# per instance via db_name, and only the master user (foundry_admin) is
# provisioned by the instance itself. THREE entities are deferred to the
# Phase-3 bootstrap Job (k8s/, one-shot post-provisioning):
#   1. the `keycloak` database
#   2. the `keycloak` PostgreSQL role (password: Secrets Manager keycloak-db)
#   3. the `realworld_app` PostgreSQL role (password: Secrets Manager app-db)
# Until that Job runs, the Secrets Manager app/keycloak credentials are
# staged but not yet usable — by design, not by accident. Instance-level
# concerns (Multi-AZ, backups, encryption) cover both databases equally.
# This comment is the contract; removing it requires updating
# docs/architecture.md.
