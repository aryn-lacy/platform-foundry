# Secrets Manager, AWS-native end to end (ADR: no third-party secret store).
# Pods consume these via the Secrets Store CSI driver (SecretProviderClass in
# k8s/*/base) — never via plain env-var manifests, never via git.
#
# Tier split mirrors ADR-008: app and keycloak have separate instances,
# separate endpoints, separate break-glass master credentials.

resource "random_password" "keycloak_admin" {
  length  = 24
  special = false
}

resource "random_password" "keycloak_db" {
  length  = 24
  special = false
}

resource "random_password" "app_db" {
  length  = 24
  special = false
}

resource "random_password" "keycloak_client" {
  length  = 32
  special = false
}

# --- application database credentials (app instance) -------------------
resource "aws_secretsmanager_secret" "app_db" {
  name = "${var.project_name}/${terraform.workspace}/app-db"
  tags = var.common_tags
}

resource "aws_secretsmanager_secret_version" "app_db" {
  secret_id = aws_secretsmanager_secret.app_db.id
  secret_string = jsonencode({
    username = "realworld_app"
    password = random_password.app_db.result
    host     = var.db_endpoints.app.host
    port     = var.db_endpoints.app.port
    dbname   = var.app_db_name
    engine   = "postgres"
  })
}

# --- keycloak database credentials (identity instance) ------------------
resource "aws_secretsmanager_secret" "keycloak_db" {
  name = "${var.project_name}/${terraform.workspace}/keycloak-db"
  tags = var.common_tags
}

resource "aws_secretsmanager_secret_version" "keycloak_db" {
  secret_id = aws_secretsmanager_secret.keycloak_db.id
  secret_string = jsonencode({
    username = "keycloak"
    password = random_password.keycloak_db.result
    host     = var.db_endpoints.keycloak.host
    port     = var.db_endpoints.keycloak.port
    dbname   = var.keycloak_db_name
    engine   = "postgres"
  })
}

# --- keycloak admin credentials ---------------------------------------
resource "aws_secretsmanager_secret" "keycloak_admin" {
  name = "${var.project_name}/${terraform.workspace}/keycloak-admin"
  tags = var.common_tags
}

resource "aws_secretsmanager_secret_version" "keycloak_admin" {
  secret_id = aws_secretsmanager_secret.keycloak_admin.id
  secret_string = jsonencode({
    username = "keycloak-admin"
    password = random_password.keycloak_admin.result
  })
}

# --- keycloak client secret (backend <-> keycloak) --------------------
resource "aws_secretsmanager_secret" "keycloak_client" {
  name = "${var.project_name}/${terraform.workspace}/keycloak-client"
  tags = var.common_tags
}

resource "aws_secretsmanager_secret_version" "keycloak_client" {
  secret_id = aws_secretsmanager_secret.keycloak_client.id
  secret_string = jsonencode({
    clientid     = "realworld-backend"
    clientsecret = random_password.keycloak_client.result
  })
}

# --- rds master credentials (break-glass, one per tier) ---------------
# Each instance's master password is generated in modules/database and
# lifecycle-ignored there (rotation is not plan-driven). Each is
# materialized here — exactly once — as its tier's break-glass credential.

resource "aws_secretsmanager_secret" "db_master" {
  for_each = toset(["app", "keycloak"])

  name = "${var.project_name}/${terraform.workspace}/db-master-${each.key}"
  tags = var.common_tags
}

resource "aws_secretsmanager_secret_version" "db_master" {
  for_each = aws_secretsmanager_secret.db_master

  secret_id = each.value.id
  secret_string = jsonencode({
    username = "foundry_admin"
    password = var.db_master_passwords[each.key]
    host     = var.db_endpoints[each.key].host
    port     = var.db_endpoints[each.key].port
    engine   = "postgres"
  })

  # Mirrors the RDS-side lifecycle ignore: written once at creation. If the
  # upstream random ever regenerated, RDS keeps the OLD password (ignored
  # there) — this ignore keeps the secret consistent with it instead of
  # silently updating to a value the database would reject. Rotation is a
  # runbook operation (modify-db-password + update-secret, atomically);
  # see docs/runbooks/.
  lifecycle {
    ignore_changes = [secret_string]
  }
}

# IAM read policy for the CSI driver's controller role (Pod Identity).
data "aws_iam_policy_document" "csi_read" {
  statement {
    sid = "ReadWorkloadSecrets"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = [
      aws_secretsmanager_secret.app_db.arn,
      aws_secretsmanager_secret.keycloak_db.arn,
      aws_secretsmanager_secret.keycloak_admin.arn,
      aws_secretsmanager_secret.keycloak_client.arn,
      aws_secretsmanager_secret.db_master["app"].arn,
      aws_secretsmanager_secret.db_master["keycloak"].arn,
    ]
  }
}

resource "aws_iam_policy" "csi_read" {
  name   = "${var.project_name}-${terraform.workspace}-secrets-csi-read"
  policy = data.aws_iam_policy_document.csi_read.json
  tags   = var.common_tags
}
