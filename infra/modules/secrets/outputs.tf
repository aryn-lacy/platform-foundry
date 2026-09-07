output "secret_names" {
  value = {
    app_db          = aws_secretsmanager_secret.app_db.name
    keycloak_db     = aws_secretsmanager_secret.keycloak_db.name
    keycloak_admin  = aws_secretsmanager_secret.keycloak_admin.name
    keycloak_client = aws_secretsmanager_secret.keycloak_client.name
    db_master       = aws_secretsmanager_secret.db_master.name
  }
}
output "csi_read_policy_arn" { value = aws_iam_policy.csi_read.arn }
