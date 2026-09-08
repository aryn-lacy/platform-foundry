# Argo CD bootstrapped by OpenTofu: the GitOps control plane is provisioned
# as part of the estate; everything AFTER first boot is managed by Argo
# itself (the argocd/ directory in the repo root takes over).
#
# Provider configuration is module-local and depends only on variables, so
# it validates cleanly. The cluster endpoint/CA arrive as module inputs from
# the eks module outputs — two-phase apply (cluster, then this module) is
# the documented operational order in a real landing zone.

provider "helm" {
  kubernetes {
    host                   = var.cluster_endpoint
    cluster_ca_certificate = base64decode(var.cluster_ca_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks", "get-token",
        "--cluster-name", var.cluster_name,
        "--region", var.aws_region,
      ]
    }
  }
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = var.chart_version

  values = [
    yamlencode({
      configs = {
        params = {
          "server.insecure" = true # TLS terminates at the platform edge
        }
      }
    })
  ]
}
