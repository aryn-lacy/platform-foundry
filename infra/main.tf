provider "aws" {
  region = var.aws_region

  assume_role {
    role_arn     = var.landing_zone_role_arn
    session_name = "platform-foundry-${terraform.workspace}"
  }

  default_tags {
    tags = {
      Project     = "platform-foundry"
      Environment = terraform.workspace
      ManagedBy   = "opentofu"
      Repository  = "aryn-lacy/platform-foundry"
    }
  }
}
