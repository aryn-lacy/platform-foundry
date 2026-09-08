output "app_endpoint_host" {
  description = "App-tier RDS writer host."
  value       = aws_db_instance.this["app"].address
}

output "app_endpoint_port" {
  value = aws_db_instance.this["app"].port
}

output "keycloak_endpoint_host" {
  description = "Identity-tier (Keycloak) RDS writer host."
  value       = aws_db_instance.this["keycloak"].address
}

output "keycloak_endpoint_port" {
  value = aws_db_instance.this["keycloak"].port
}

output "app_database_name" {
  value = aws_db_instance.this["app"].db_name
}

output "keycloak_database_name" {
  value = aws_db_instance.this["keycloak"].db_name
}

output "security_group_id" {
  value = aws_security_group.db.id
}

output "master_secret_candidates" {
  description = "Per-tier master credential values (feed the break-glass secrets in modules/secrets; never rendered)."
  value       = { for k, p in random_password.master : k => p.result }
  sensitive   = true
}
