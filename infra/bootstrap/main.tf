# Bootstrap stack — the one manual step, documented (see README).
# Creates remote state foundations for ALL workspaces: one bucket + one lock
# table per organization, key prefixes per workspace.

terraform {
  required_version = ">= 1.8.0"
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

resource "aws_dynamodb_table" "lock" {
  name         = "${var.bucket_name_prefix}-tflock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    recovery_period_in_days = 35
    enabled                 = true
  }
  tags = { Project = "platform-foundry", Purpose = "tflock" }
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "bucket_name_prefix" {
  type    = string
  default = "platform-foundry"
}
