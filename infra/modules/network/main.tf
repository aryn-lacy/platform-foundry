data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # /18 VPC -> per-AZ slices: private gets the largest share (workloads + data tier)
  public_subnets  = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 4, i)]
  private_subnets = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 4, i + 8)]

  subnet_tags = merge(var.common_tags, {
    # Kubernetes discovery tags — the Auto Mode load balancer controller
    # places public-facing Services in subnets tagged kubernetes.io/role/elb
    "kubernetes.io/role/elb"                                           = "1"
    "kubernetes.io/role/internal-elb"                                  = "1"
    "kubernetes.io/cluster/${var.project_name}-${terraform.workspace}" = "shared"
  })
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.common_tags, { Name = "${var.project_name}-${terraform.workspace}" })
}

# Default SG exists whether we declare it or not — pin it empty
# (checkov CKV2_AWS_12): all traffic flows through explicitly declared SGs.
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.common_tags, { Name = "${var.project_name}-${terraform.workspace}-default-empty" })
}

# Network-module CMK (flow-log group encryption, checkov CKV_AWS_158) with
# an explicit key policy (checkov CKV2_AWS_64).
data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

resource "aws_kms_key" "network" {
  description             = "${var.project_name}-${terraform.workspace} network"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = var.common_tags
}

resource "aws_kms_key_policy" "network" {
  key_id = aws_kms_key.network.id
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
        # CloudWatch Logs must be able to use the key for the encrypted
        # flow-log group — without this, delivery fails (review C1).
        Sid       = "AllowLogsServiceUse"
        Effect    = "Allow"
        Principal = { Service = "logs.${data.aws_region.current.name}.amazonaws.com" }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
        ]
        Resource = "*"
        Condition = {
          StringEquals = { "kms:ViaService" = "logs.${data.aws_region.current.name}.amazonaws.com" }
        }
      },
    ]
  })
}

data "aws_region" "current" {}

# VPC flow logs to CloudWatch (checkov CKV2_AWS_11): historical network
# telemetry for the bottleneck-debugging requirement. 365d retention
# (CKV_AWS_338) and CMK encryption (CKV_AWS_158) per gate.
resource "aws_cloudwatch_log_group" "flow" {
  name              = "/aws/vpc/${var.project_name}-${terraform.workspace}"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.network.arn
  tags              = var.common_tags
}

# Flow Logs assume this service role (checkov CKV2_AWS_11 wiring).
data "aws_iam_policy_document" "flowlogs_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "flowlogs" {
  name               = "${var.project_name}-${terraform.workspace}-flowlogs"
  assume_role_policy = data.aws_iam_policy_document.flowlogs_assume.json
  tags               = var.common_tags
}

data "aws_iam_policy_document" "flowlogs_write" {
  # CreateLogGroup on the exact ARN only (AWS-0057: sensitive
  # action must not sit on a wildcarded resource); stream/event ops on the
  # group's children.
  statement {
    effect    = "Allow"
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream"]
    resources = [aws_cloudwatch_log_group.flow.arn]
  }

  statement {
    effect = "Allow"
    actions = [
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]
    resources = ["${aws_cloudwatch_log_group.flow.arn}:*"] # PutLogEvents targets child stream ARNs — the wildcard suffix is structural (streams are created at delivery time); scope is this one group's children, not account-wide
  }
}

resource "aws_iam_role_policy" "flowlogs" {
  name   = "write-flow-logs"
  role   = aws_iam_role.flowlogs.id
  policy = data.aws_iam_policy_document.flowlogs_write.json
}

resource "aws_flow_log" "this" {
  vpc_id               = aws_vpc.this.id
  traffic_type         = "ALL"
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.flow.arn
  iam_role_arn         = aws_iam_role.flowlogs.arn
  tags                 = var.common_tags
}

resource "aws_subnet" "public" {
  for_each = { for idx, az in local.azs : az => idx }

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = local.public_subnets[each.value]
  map_public_ip_on_launch = false

  tags = merge(local.subnet_tags, { Name = "${var.project_name}-${terraform.workspace}-public-${each.key}" })
}

resource "aws_subnet" "private" {
  for_each = { for idx, az in local.azs : az => idx }

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = local.private_subnets[each.value]

  tags = merge(local.subnet_tags, { Name = "${var.project_name}-${terraform.workspace}-private-${each.key}" })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = var.common_tags
}

# Single NAT gateway: acceptable for a dev-tier stack; prod-grade HA would
# provision one per AZ. Deliberate trade-off — see docs/decisions/ and the
# assumption register.
resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[local.azs[0]].id

  tags = merge(var.common_tags, { Name = "${var.project_name}-${terraform.workspace}-nat" })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = var.common_tags
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(var.common_tags, { Name = "${var.project_name}-${terraform.workspace}-public" })
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  for_each = aws_subnet.private

  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }

  tags = merge(var.common_tags, { Name = "${var.project_name}-${terraform.workspace}-private-${each.key}" })
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}
