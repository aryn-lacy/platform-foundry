# EKS Auto Mode (ADR-001): AWS operates nodes, load balancer controller,
# and storage. No managed node groups, no self-installed controllers.

data "aws_partition" "current" {}

resource "aws_eks_cluster" "this" {
  name     = "${var.project_name}-${terraform.workspace}"
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_public_access  = var.endpoint_public_access
    endpoint_private_access = var.endpoint_private_access
    public_access_cidrs     = var.allowed_api_cidrs
  }

  # Auto Mode: compute + storage + load balancing, AWS-operated.
  compute_config {
    enabled       = true
    node_pools    = ["general-purpose"]
    node_role_arn = aws_iam_role.node.arn
  }

  kubernetes_network_config {
    # Egress flows through the VPC NAT gateway (deterministic EIP, owned by
    # modules/network). A dedicated elastic_ip_config is unnecessary here.
  }

  storage_config {
    block_storage {
      enabled = true
    }
  }

  # Auto Mode requires the cluster security + access entry model.
  access_config {
    authentication_mode = "API"
  }

  tags = merge(var.common_tags, { Name = "${var.project_name}-${terraform.workspace}" })

  depends_on = [aws_iam_role_policy_attachment.cluster]
}

# ------------------------------------------------------------------
# Cluster IAM
# ------------------------------------------------------------------

data "aws_iam_policy_document" "cluster_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${var.project_name}-${terraform.workspace}-cluster"
  assume_role_policy = data.aws_iam_policy_document.cluster_assume.json
  tags               = var.common_tags
}

resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSClusterPolicy"
}

# Auto Mode node role: the role nodes assume. Broadly resembling the
# AmazonEKSNodeRole policy set required by Auto Mode.
data "aws_iam_policy_document" "node_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name               = "${var.project_name}-${terraform.workspace}-node"
  assume_role_policy = data.aws_iam_policy_document.node_assume.json
  tags               = var.common_tags
}

resource "aws_iam_role_policy_attachment" "node" {
  for_each = toset([
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEBSCSIDriverPolicy",
  ])

  role       = aws_iam_role.node.name
  policy_arn = each.value
}

# ------------------------------------------------------------------
# Add-ons (validated by AWS; versions resolved at cluster version)
# ------------------------------------------------------------------

resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "eks-pod-identity-agent"
  resolve_conflicts_on_create = "OVERWRITE"
  tags                        = var.common_tags
}

resource "aws_eks_addon" "secrets_csi" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "aws-secrets-store-csi-driver-provider"
  resolve_conflicts_on_create = "OVERWRITE"
  tags                        = var.common_tags
}

resource "aws_eks_addon" "adot" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "adot"
  resolve_conflicts_on_create = "OVERWRITE"
  tags                        = var.common_tags
}

resource "aws_eks_addon" "metrics_server" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "metrics-server"
  resolve_conflicts_on_create = "OVERWRITE"
  tags                        = var.common_tags
}

resource "aws_eks_addon" "cloudwatch_observability" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "amazon-cloudwatch-observability"
  resolve_conflicts_on_create = "OVERWRITE"
  tags                        = var.common_tags
}

# ------------------------------------------------------------------
# Pod Identity: controller role (ADR-002 — app pods carry no AWS IAM)
# ------------------------------------------------------------------

data "aws_iam_policy_document" "pod_identity_trust" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

# Pod Identity + ASCP credential model (ADR-002, corrected):
#
# ASCP resolves AWS identity from the MOUNTING POD's service account —
# never its own (verified in ASCP server/server.go: it reads
# csi.storage.k8s.io/serviceAccount.name/.tokens from the mount request
# and exchanges that SA's Pod Identity token). Therefore:
#   - There is NO controller-level association to create here. A
#     provider-SA association would be dead code.
#   - Associations are PER WORKLOAD (backend, keycloak) and land with the
#     workloads themselves in Phase 3, when their namespaces/service
#     accounts exist: one aws_eks_pod_identity_association each, bound to
#     this role, with usePodIdentity: "true" in the SecretProviderClass.
#   - App pods hold no AWS credentials, ship no AWS SDK, and make no AWS
#     calls; their SAs carry this read-scoped association, which ASCP
#     borrows. "Zero IAM" was the wrong claim — "zero credentials, zero
#     calls, read-only scoped association" is the accurate posture.
resource "aws_iam_role" "this_controller" {
  name               = "${var.project_name}-${terraform.workspace}-podid"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
  tags               = var.common_tags
}
