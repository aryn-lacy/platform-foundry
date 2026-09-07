module "secrets" {
  source = "./modules/secrets"

  project_name       = var.project_name
  db_endpoint        = module.rds_postgres.endpoint_host
  db_port            = module.rds_postgres.endpoint_port
  app_db_name        = module.rds_postgres.app_database_name
  keycloak_db_name   = module.rds_postgres.keycloak_database_name
  db_master_password = module.rds_postgres.master_secret_candidate
  common_tags        = var.common_tags
}
