variable "project_name" {
  type = string
}

variable "instance_class" {
  type = string
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
