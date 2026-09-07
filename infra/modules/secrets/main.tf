# Secrets Manager, AWS-native end to end (ADR: no third-party secret store).
# Pods consume these via the Secrets Store CSI driver (SecretProviderClass in
# k8s/*/base) — never via plain env-var manifests, never via git.

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

# --- application database credentials ---------------------------------
resource "aws_secretsmanager_secret" "app_db" {
  name = "${var.project_name}/${terraform.workspace}/app-db"
  tags = var.common_tags
}

resource "aws_secretsmanager_secret_version" "app_db" {
  secret_id = aws_secretsmanager_secret.app_db.id
  secret_string = jsonencode({
    username = "realworld_app"
    password = random_password.app_db.result
    host     = var.db_endpoint
    port     = var.db_port
    dbname   = var.app_db_name
    engine   = "postgres"
  })
}

# --- keycloak database credentials ------------------------------------
resource "aws_secretsmanager_secret" "keycloak_db" {
  name = "${var.project_name}/${terraform.workspace}/keycloak-db"
  tags = var.common_tags
}

resource "aws_secretsmanager_secret_version" "keycloak_db" {
  secret_id = aws_secretsmanager_secret.keycloak_db.id
  secret_string = jsonencode({
    username = "keycloak"
    password = random_password.keycloak_db.result
    host     = var.db_endpoint
    port     = var.db_port
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
    client-id     = "realworld-backend"
    client-secret = random_password.keycloak_admin.result # rotated independently in prod
  })
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
    ]
  }
}

resource "aws_iam_policy" "csi_read" {
  name   = "${var.project_name}-${terraform.workspace}-secrets-csi-read"
  policy = data.aws_iam_policy_document.csi_read.json
  tags   = var.common_tags
}
