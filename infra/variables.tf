# ------------------------------------------------------------------
# Landing zone / provider wiring
# ------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region for the workload stack."
  type        = string
  default     = "us-east-1"
}

variable "landing_zone_role_arn" {
  description = "IAM role to assume in the target landing zone account. Provided per environment in envs/*.tfvars — the workload account boundary this stack respects."
  type        = string
}

variable "project_name" {
  description = "Name prefix for resources (buckets, clusters, repos)."
  type        = string
  default     = "platform-foundry"
}

# ------------------------------------------------------------------
# Network
# ------------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block for the workload VPC. Must be inside the address space delegated by the landing zone's IPAM (assumed)."
  type        = string
  default     = "10.40.0.0/18"
}

variable "az_count" {
  description = "Number of availability zones to spread across (min 2 for Multi-AZ)."
  type        = number
  default     = 3
}

# ------------------------------------------------------------------
# EKS
# ------------------------------------------------------------------

variable "kubernetes_version" {
  description = "EKS Kubernetes version."
  type        = string
  default     = "1.31"
}

variable "endpoint_public_access" {
  description = "Expose the EKS API endpoint publicly. Landing-zone bastion/VPN access is the alternative."
  type        = bool
  default     = true
}

variable "endpoint_private_access" {
  description = "EKS API endpoint reachable from within the VPC."
  type        = bool
  default     = true
}

variable "allowed_api_cidrs" {
  description = "CIDRs permitted to reach the EKS public API endpoint. Landing-zone corporate egress ranges, provided per environment."
  type        = list(string)
  default     = []
}

# ------------------------------------------------------------------
# RDS
# ------------------------------------------------------------------

variable "db_instance_class" {
  description = "RDS instance class. Sized per environment in tfvars."
  type        = string
  default     = "db.t4g.medium"
}

variable "db_backup_retention_days" {
  description = "Automated backup retention. Requirement: at least daily backups — retention expressed in days."
  type        = number
  default     = 14
}

variable "db_backup_window" {
  description = "Preferred backup window (UTC). Must not collide with the maintenance window."
  type        = string
  default     = "03:00-04:00"
}

variable "db_maintenance_window" {
  description = "Preferred maintenance window (UTC), placed outside the backup window."
  type        = string
  default     = "sun:04:30-sun:05:30"
}

variable "db_deletion_protection" {
  description = "RDS deletion protection. Prod: true. Dev may relax to false for teardown speed."
  type        = bool
  default     = true
}

# ------------------------------------------------------------------
# Argo CD
# ------------------------------------------------------------------

variable "argocd_chart_version" {
  description = "Argo CD Helm chart version (bootstrapped by Terraform)."
  type        = string
  default     = "7.7.x"
}

# Argo CD repository credentials are provisioned OUT-OF-BAND (documented in
# infra/modules/argocd) — deliberately not a root variable.

# ------------------------------------------------------------------
# Convention
# ------------------------------------------------------------------

variable "common_tags" {
  description = "Extra tags merged into default_tags."
  type        = map(string)
  default     = {}
}
