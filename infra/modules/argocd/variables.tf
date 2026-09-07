terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
  }
}

variable "project_name" {
  type = string
}
variable "cluster_name" {
  type = string
}
variable "cluster_endpoint" {
  type = string
}
variable "cluster_ca_data" {
  type      = string
  sensitive = true
}
variable "aws_region" {
  type = string
}
variable "chart_version" {
  type = string
}
variable "common_tags" {
  type    = map(string)
  default = {}
}
