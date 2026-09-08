module "argocd" {
  source = "./modules/argocd"

  project_name     = var.project_name
  cluster_name     = module.eks.cluster_name
  cluster_endpoint = module.eks.cluster_endpoint
  cluster_ca_data  = module.eks.cluster_certificate_authority_data
  aws_region       = var.aws_region
  chart_version    = var.argocd_chart_version
  common_tags      = var.common_tags
}
