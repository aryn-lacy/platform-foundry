# dev landing zone
landing_zone_role_arn = "arn:aws:iam::123412341234:role/platform-foundry-dev"

aws_region = "us-east-1"
vpc_cidr   = "10.40.0.0/18"
az_count   = 3

kubernetes_version = "1.31"

db_instance_class        = "db.t4g.medium"
db_deletion_protection   = false
db_backup_retention_days = 7
