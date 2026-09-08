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

variable "workload_associations" {
  description = "Per-workload Pod Identity associations (ADR-002): map of workload key -> {namespace, service_account}. Bound to the shared read-scoped role; declarative bindings — referenced SAs may not exist yet (inert until first token request). Renaming a workload SA requires updating this map in the same PR as the k8s manifest."
  type = map(object({
    namespace       = string
    service_account = string
  }))
}

variable "common_tags" {
  type    = map(string)
  default = {}
}
