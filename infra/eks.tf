module "eks" {
  source = "./modules/eks"

  project_name            = var.project_name
  kubernetes_version      = var.kubernetes_version
  vpc_id                  = module.network.vpc_id
  subnet_ids              = module.network.private_subnet_ids
  endpoint_public_access  = var.endpoint_public_access
  endpoint_private_access = var.endpoint_private_access
  allowed_api_cidrs       = var.allowed_api_cidrs
  common_tags             = var.common_tags
}

# Attach the secrets CSI read policy to the shared read-scoped role
# (ADR-002 revised: per-workload Pod Identity associations borrow this
# role at mount time; app pods hold no credentials, SDK, or AWS calls).
resource "aws_iam_role_policy_attachment" "csi_read" {
  role       = module.eks.pod_identity_role_name
  policy_arn = module.secrets.csi_read_policy_arn
}
