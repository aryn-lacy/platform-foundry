variable "project_name" {
  type = string
}

variable "db_endpoint" {
  type = string
}

variable "db_port" {
  type = number
}

variable "app_db_name" {
  type = string
}

variable "keycloak_db_name" {
  type = string
}

variable "db_master_password" {
  type      = string
  sensitive = true
}

variable "common_tags" {
  type    = map(string)
  default = {}
}
