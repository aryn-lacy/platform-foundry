output "connection_endpoint" { value = aws_db_instance.postgres.endpoint }
output "endpoint_host" { value = aws_db_instance.postgres.address }
output "endpoint_port" { value = aws_db_instance.postgres.port }
output "app_database_name" { value = aws_db_instance.postgres.db_name }
output "keycloak_database_name" { value = "keycloak" }
output "security_group_id" { value = aws_security_group.db.id }
output "master_secret_candidate" {
  value     = random_password.master.result
  sensitive = true
}
