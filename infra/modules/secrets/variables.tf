variable "project_name" {
  type = string
}

variable "db_endpoints" {
  description = "Per-tier RDS endpoints: host and port (app, keycloak)."
  type = object({
    app = object({
      host = string
      port = number
    })
    keycloak = object({
      host = string
      port = number
    })
  })
}

variable "app_db_name" {
  type = string
}

variable "keycloak_db_name" {
  type = string
}

variable "db_master_passwords" {
  description = "Per-tier master credential values (from modules/database; materialized once each as break-glass secrets)."
  type = object({
    app      = string
    keycloak = string
  })
  sensitive = true
}

variable "common_tags" {
  type    = map(string)
  default = {}
}
