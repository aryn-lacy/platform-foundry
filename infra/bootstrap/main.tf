# Bootstrap stack — the one manual step, documented (see README).
# Creates the remote state foundation for ALL workspaces: one versioned,
# encrypted, SSL-only S3 bucket. State locking is S3-native (use_lockfile,
# OpenTofu >= 1.10) — conditional writes against the state object itself,
# so there is no DynamoDB lock table to provision.

terraform {
  required_version = ">= 1.10.0"
}

provider "aws" {
  region = var.aws_region
}

resource "aws_s3_bucket" "state" {
  bucket = "${var.bucket_name_prefix}-tfstate"
  tags   = { Project = "platform-foundry", Purpose = "tfstate" }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "state_ssl_only" {
  statement {
    sid     = "ForceSSLOnlyAccess"
    effect  = "Deny"
    actions = ["s3:*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    resources = [aws_s3_bucket.state.arn, "${aws_s3_bucket.state.arn}/*"]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "state_ssl_only" {
  bucket = aws_s3_bucket.state.id
  policy = data.aws_iam_policy_document.state_ssl_only.json
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "bucket_name_prefix" {
  type    = string
  default = "platform-foundry"
}
