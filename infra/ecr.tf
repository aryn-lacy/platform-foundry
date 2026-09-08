module "ecr" {
  source = "./modules/ecr"

  project_name = var.project_name
  common_tags  = var.common_tags
}
