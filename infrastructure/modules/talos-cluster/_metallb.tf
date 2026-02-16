# ==============================================================================
# MetalLB Load Balancer - L2 Mode for Bare Metal LoadBalancer Services
# ==============================================================================

resource "kubernetes_namespace_v1" "metallb_system" {
  count = var.deploy_bootstrap && var.metallb_ip_range != "" ? 1 : 0

  metadata {
    name = "metallb-system"
    labels = {
      "pod-security.kubernetes.io/enforce" = "privileged"
    }
  }

  depends_on = [data.talos_cluster_health.cluster]
}

resource "helm_release" "metallb" {
  count = var.deploy_bootstrap && var.metallb_ip_range != "" ? 1 : 0

  name             = "metallb"
  repository       = "https://metallb.github.io/metallb"
  chart            = "metallb"
  version          = "0.15.3"
  namespace        = kubernetes_namespace_v1.metallb_system[0].metadata[0].name
  create_namespace = false
  wait             = true
  timeout          = 300

  depends_on = [data.talos_cluster_health.cluster]
}

resource "kubectl_manifest" "metallb_ip_pool" {
  count = var.deploy_bootstrap && var.metallb_ip_range != "" ? 1 : 0

  validate_schema = false

  yaml_body = <<-YAML
    apiVersion: metallb.io/v1beta1
    kind: IPAddressPool
    metadata:
      name: default-pool
      namespace: metallb-system
    spec:
      addresses:
        - ${var.metallb_ip_range}
  YAML

  depends_on = [helm_release.metallb]
}

resource "kubectl_manifest" "metallb_l2_advertisement" {
  count = var.deploy_bootstrap && var.metallb_ip_range != "" ? 1 : 0

  validate_schema = false

  yaml_body = <<-YAML
    apiVersion: metallb.io/v1beta1
    kind: L2Advertisement
    metadata:
      name: default
      namespace: metallb-system
    spec:
      ipAddressPools:
        - default-pool
  YAML

  depends_on = [helm_release.metallb]
}
