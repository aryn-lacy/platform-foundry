output "vpc_id" {
  description = "Workload VPC."
  value       = module.network.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnets (workloads + data tier)."
  value       = module.network.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnets (load balancers, NAT)."
  value       = module.network.public_subnet_ids
}

output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint."
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 CA data for kubeconfig generation."
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_oidc_issuer_url" {
  description = "Cluster OIDC issuer (reference; Pod Identity is the workload-identity mechanism — see ADR-002)."
  value       = module.eks.cluster_oidc_issuer_url
}

output "app_database_endpoint" {
  description = "App-tier RDS writer endpoint (host:port)."
  value       = "${module.rds_postgres.app_endpoint_host}:${module.rds_postgres.app_endpoint_port}"
}

output "keycloak_database_endpoint" {
  description = "Identity-tier RDS writer endpoint (host:port)."
  value       = "${module.rds_postgres.keycloak_endpoint_host}:${module.rds_postgres.keycloak_endpoint_port}"
}

output "app_database_name" {
  description = "Application database name (on the shared instance)."
  value       = module.rds_postgres.app_database_name
}

output "keycloak_database_name" {
  description = "Keycloak database name (on the shared instance)."
  value       = module.rds_postgres.keycloak_database_name
}

output "secrets" {
  description = "Secret names created for workload consumption (values live in Secrets Manager only)."
  value       = module.secrets.secret_names
}

output "ecr_repository_urls" {
  description = "Image repositories, keyed by service."
  value       = module.ecr.repository_urls
}

output "argocd_server_url" {
  description = "Argo CD server (port-forward or ingress per environment)."
  value       = module.argocd.server_url
}
