variable "project_name" {
  type = string
}

variable "kubernetes_version" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "endpoint_public_access" {
  type = bool
}

variable "endpoint_private_access" {
  type = bool
}

variable "allowed_api_cidrs" {
  type = list(string)
}

variable "common_tags" {
  type    = map(string)
  default = {}
}
