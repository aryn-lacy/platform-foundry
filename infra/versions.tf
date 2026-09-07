# Terraform settings — the ONLY terraform{} block in this module.
#
# Backend configuration lives here (not in a separate backend.tf) because
# OpenTofu permits exactly one terraform settings block per module.
# The backend resources (S3 + DynamoDB) are created by infra/bootstrap/.

terraform {
  required_version = ">= 1.8.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.100"
    }
  }

  # Per-workspace key is supplied at init time:
  #   tofu init -backend-config="key=dev/terraform.tfstate"
  # Keeping dev/prod state separated while sharing the bootstrap foundation.
  backend "s3" {
    bucket         = "platform-foundry-tfstate"
    key            = "workspaces/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "platform-foundry-tflock"
    encrypt        = true
  }
}
