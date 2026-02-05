# ==============================================================================
# MetalLB Load Balancer - L2 Mode for Bare Metal LoadBalancer Services
# ==============================================================================

resource "kubernetes_namespace_v1" "metallb_system" {
  count = var.deploy_bootstrap && var.metallb_ip_range != "" ? 1 : 0

  metadata {
    name = "metallb-system"
  }

  depends_on = [talos_machine_bootstrap.cluster]
}

resource "helm_release" "metallb" {
  count = var.deploy_bootstrap && var.metallb_ip_range != "" ? 1 : 0

  name             = "metallb"
  repository       = "https://metallb.github.io/metallb"
  chart            = "metallb"
  version          = "0.14.9"
  namespace        = "metallb-system"
  create_namespace = false
  wait             = true
  timeout          = 300

  depends_on = [kubernetes_namespace_v1.metallb_system]
}

resource "kubernetes_manifest" "metallb_ippool" {
  count = var.deploy_bootstrap && var.metallb_ip_range != "" ? 1 : 0

  manifest = {
    apiVersion = "metallb.io/v1beta1"
    kind       = "IPAddressPool"
    metadata = {
      name      = "default-pool"
      namespace = "metallb-system"
    }
    spec = {
      addresses = [var.metallb_ip_range]
    }
  }

  depends_on = [helm_release.metallb]
}

resource "kubernetes_manifest" "metallb_l2advertisement" {
  count = var.deploy_bootstrap && var.metallb_ip_range != "" ? 1 : 0

  manifest = {
    apiVersion = "metallb.io/v1beta1"
    kind       = "L2Advertisement"
    metadata = {
      name      = "default"
      namespace = "metallb-system"
    }
    spec = {
      ipAddressPools = ["default-pool"]
    }
  }

  depends_on = [kubernetes_manifest.metallb_ippool]
}
