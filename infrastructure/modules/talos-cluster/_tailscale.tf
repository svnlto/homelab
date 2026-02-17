# ==============================================================================
# Tailscale Kubernetes Operator - Enables Tailscale access to cluster services
# ==============================================================================

resource "kubernetes_namespace_v1" "tailscale" {
  count = var.deploy_bootstrap && var.tailscale_enabled ? 1 : 0

  metadata {
    name = "tailscale"
    labels = {
      "pod-security.kubernetes.io/enforce" = "privileged"
    }
  }

  depends_on = [data.talos_cluster_health.cluster]
}

resource "helm_release" "tailscale_operator" {
  count = var.deploy_bootstrap && var.tailscale_enabled ? 1 : 0

  name             = "tailscale-operator"
  repository       = "https://pkgs.tailscale.com/helmcharts"
  chart            = "tailscale-operator"
  version          = "1.94.2"
  namespace        = kubernetes_namespace_v1.tailscale[0].metadata[0].name
  create_namespace = false
  wait             = true
  timeout          = 300

  values = [yamlencode({
    oauth = {
      clientId     = var.tailscale_oauth_client_id
      clientSecret = var.tailscale_oauth_client_secret
    }
    operatorConfig = {
      defaultTags = ["tag:k8s"]
    }
  })]

  depends_on = [data.talos_cluster_health.cluster]
}
