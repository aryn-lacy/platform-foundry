# Two images (backend, frontend); Keycloak runs the stock upstream image —
# configured, never built (ADR posture: complexity lives in the rig).

resource "aws_ecr_repository" "this" {
  for_each = toset(["backend", "frontend"])

  name                 = "${var.project_name}/${each.key}"
  image_tag_mutability = "IMMUTABLE"

  # ECR encrypted with a dedicated CMK (checkov CKV_AWS_136).
  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.ecr.arn
  }

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = var.common_tags
}

# Dedicated CMK for ECR image encryption (checkov CKV_AWS_136) with an
# explicit key policy (checkov CKV2_AWS_64).
resource "aws_kms_key" "ecr" {
  description             = "${var.project_name}-${terraform.workspace} ECR"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = var.common_tags
}

resource "aws_kms_key_policy" "ecr" {
  key_id = aws_kms_key.ecr.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "Enable IAM User Permissions"
        Effect    = "Allow"
        Principal = { AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        # ECR + KMS is grant-based: the PUSHING/PULLING identity creates a
        # grant on the key; ECR then encrypts/decrypts layers under that
        # grant (review round-2 I1). The service-principal Decrypt form
        # does not match AWS's documented model.
        Sid       = "AllowPushPullGrantCreation"
        Effect    = "Allow"
        Principal = { AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action = [
          "kms:CreateGrant",
          "kms:RetireGrant",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*",
        ]
        Resource = "*"
        Condition = {
          StringEquals = { "kms:ViaService" = "ecr.${data.aws_region.current.name}.amazonaws.com" }
        }
      },
    ]
  })
}

data "aws_region" "current" {}

data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

resource "aws_ecr_lifecycle_policy" "this" {
  for_each = aws_ecr_repository.this

  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 30 tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 30
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Expire untagged images older than 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = { type = "expire" }
      },
    ]
  })
}
