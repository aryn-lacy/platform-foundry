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
