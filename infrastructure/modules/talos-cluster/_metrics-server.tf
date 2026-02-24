# ==============================================================================
# Metrics Server - Resource Metrics for kubectl top and HPA
# ==============================================================================

resource "helm_release" "metrics_server" {
  count = var.deploy_bootstrap && var.metrics_server_enabled ? 1 : 0

  name             = "metrics-server"
  repository       = "https://kubernetes-sigs.github.io/metrics-server/"
  chart            = "metrics-server"
  version          = "3.13.0"
  namespace        = "kube-system"
  create_namespace = false
  wait             = true
  timeout          = 300

  values = [yamlencode({
    args = ["--kubelet-insecure-tls"]
    resources = {
      requests = { cpu = "50m", memory = "64Mi" }
      limits   = { cpu = "200m", memory = "256Mi" }
    }
  })]

  depends_on = [data.talos_cluster_health.cluster]
}
