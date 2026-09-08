# Two RDS PostgreSQL instances — identity tier isolated from application
# tier (ADR-008). Module contains per-tier for_each; this file names the
# domain (rds-postgres) and instantiates it.

module "rds_postgres" {
  source = "./modules/database"

  project_name = var.project_name

  instance_classes = {
    app      = var.db_instance_class_app
    keycloak = var.db_instance_class_keycloak
  }

  vpc_id                = module.network.vpc_id
  subnet_ids            = module.network.private_subnet_ids
  allowed_cidrs         = [module.network.vpc_cidr_block]
  backup_retention_days = var.db_backup_retention_days
  backup_window         = var.db_backup_window
  maintenance_window    = var.db_maintenance_window
  deletion_protection   = var.db_deletion_protection
  common_tags           = var.common_tags
}
