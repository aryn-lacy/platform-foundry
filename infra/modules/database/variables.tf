variable "project_name" {
  type = string
}

variable "instance_classes" {
  description = "Per-tier RDS instance classes (app, keycloak). Sized per environment in tfvars."
  type        = map(string)
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "allowed_cidrs" {
  type = list(string)
}

variable "backup_retention_days" {
  type = number
}

variable "backup_window" {
  type = string
}

variable "maintenance_window" {
  type = string
}

variable "deletion_protection" {
  type = bool
}

variable "common_tags" {
  type    = map(string)
  default = {}
}
