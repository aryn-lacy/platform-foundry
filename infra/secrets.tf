# Secrets for both tiers, materialized once. Endpoints and master
# credentials arrive per-tier from the database module.

module "secrets" {
  source = "./modules/secrets"

  project_name = var.project_name

  db_endpoints = {
    app = {
      host = module.rds_postgres.app_endpoint_host
      port = module.rds_postgres.app_endpoint_port
    }
    keycloak = {
      host = module.rds_postgres.keycloak_endpoint_host
      port = module.rds_postgres.keycloak_endpoint_port
    }
  }

  app_db_name      = module.rds_postgres.app_database_name
  keycloak_db_name = module.rds_postgres.keycloak_database_name

  db_master_passwords = module.rds_postgres.master_secret_candidates

  common_tags = var.common_tags
}
