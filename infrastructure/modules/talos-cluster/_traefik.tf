# ==============================================================================
# Traefik Ingress Controller - Per-Cluster Ingress via MetalLB LoadBalancer
# ==============================================================================

resource "kubernetes_namespace_v1" "traefik" {
  count = var.deploy_bootstrap && var.traefik_enabled ? 1 : 0

  metadata {
    name = "traefik"
    labels = {
      "pod-security.kubernetes.io/enforce" = "privileged"
    }
  }

  depends_on = [data.talos_cluster_health.cluster]
}

resource "helm_release" "traefik" {
  count = var.deploy_bootstrap && var.traefik_enabled ? 1 : 0

  name             = "traefik"
  repository       = "https://traefik.github.io/charts"
  chart            = "traefik"
  version          = "34.3.0"
  namespace        = kubernetes_namespace_v1.traefik[0].metadata[0].name
  create_namespace = false
  wait             = true
  timeout          = 300

  values = [yamlencode({
    service = {
      type = "LoadBalancer"
    }
    ports = {
      web = {
        port        = 8000
        exposedPort = 80
      }
      websecure = {
        port        = 8443
        exposedPort = 443
      }
    }
    ingressClass = {
      enabled        = true
      isDefaultClass = true
    }
    ingressRoute = {
      dashboard = {
        enabled = false
      }
    }
    providers = {
      kubernetesIngress = {
        enabled = true
      }
    }
  })]

  depends_on = [helm_release.metallb]
}
