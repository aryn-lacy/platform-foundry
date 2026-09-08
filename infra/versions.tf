# Terraform settings — the ONLY terraform{} block in this module.
#
# Backend configuration lives here (not in a separate backend.tf) because
# OpenTofu permits exactly one terraform settings block per module.
# The state bucket is created by infra/bootstrap/; locking is S3-native
# (use_lockfile — conditional writes), so no lock table exists anywhere.
#
# OpenTofu, not Terraform (ADR-010, full argument in docs/decisions/):
# a deliberate choice of convenience and ecosystem fit — the authoring
# environment and personal IaC standardize on OpenTofu; open-source CI/CD
# tooling (Digger, OpenTaco-class runners) integrates more smoothly with
# OpenTofu; and the Terraform-equivalent binary is a drop-in replacement
# for this configuration should a landing zone mandate it (the HCL is
# tool-identical; only the runner differs). Enterprise Terraform features
# (state/workspaces as a service) carry enterprise pricing that personal
# projects have no reason to pay when an open, LinuxFoundation-governed
# alternative implements the same language.

terraform {
  # >= 1.10: S3-native state locking (use_lockfile) available in the backend.
  required_version = ">= 1.10.0"

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
    bucket = "platform-foundry-tfstate"
    key    = "workspaces/terraform.tfstate"
    region = "us-east-1"

    encrypt      = true
    use_lockfile = true # S3-native locking via conditional writes; no DynamoDB lock table
  }
}
