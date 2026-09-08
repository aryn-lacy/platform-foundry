# prod landing zone
landing_zone_role_arn = "arn:aws:iam::567856785678:role/platform-foundry-prod"

aws_region = "us-east-1"
vpc_cidr   = "10.44.0.0/18"
az_count   = 3

kubernetes_version = "1.36"

db_instance_class_app      = "db.t4g.large"
db_instance_class_keycloak = "db.t4g.medium"
db_deletion_protection     = true
db_backup_retention_days   = 30

common_tags = { Tier = "prod" }
