provider "kubernetes" {
  config_path = var.kubeconfig_path
}

provider "helm" {
  kubernetes = {
    config_path = var.kubeconfig_path
  }
}

resource "kubernetes_namespace_v1" "flux_system" {
  metadata {
    name = var.namespace
  }
}

resource "helm_release" "flux_operator" {
  name       = "flux-operator"
  repository = "oci://ghcr.io/controlplaneio-fluxcd/charts"
  chart      = "flux-operator"
  version    = var.operator_chart_version
  namespace  = kubernetes_namespace_v1.flux_system.metadata[0].name

  depends_on = [kubernetes_namespace_v1.flux_system]
}

locals {
  flux_instance = yamlencode({
    apiVersion = "fluxcd.controlplane.io/v1"
    kind       = "FluxInstance"
    metadata = {
      name      = "flux"
      namespace = var.namespace
      annotations = {
        "fluxcd.controlplane.io/reconcile"        = "enabled"
        "fluxcd.controlplane.io/reconcileEvery"   = "1h"
        "fluxcd.controlplane.io/reconcileTimeout" = "5m"
      }
    }
    spec = {
      distribution = {
        version  = var.flux_version
        registry = "ghcr.io/fluxcd"
        artifact = "oci://ghcr.io/controlplaneio-fluxcd/flux-operator-manifests"
      }
      components = var.flux_components
      cluster = {
        type          = "kubernetes"
        size          = var.cluster_size
        multitenant   = var.multitenant
        networkPolicy = true
        domain        = "cluster.local"
      }
      sync = {
        kind = "GitRepository"
        url  = var.repo_url
        ref  = var.repo_ref
        path = var.sync_path
      }
    }
  })
}

resource "time_sleep" "wait_for_operator_crds" {
  depends_on      = [helm_release.flux_operator]
  create_duration = "30s"
}

# kubectl, not kubernetes_manifest: the FluxInstance CRD does not exist until
# the operator chart is installed, so a manifest resource fails at plan time.
resource "null_resource" "flux_instance" {
  triggers = {
    kubeconfig_path = var.kubeconfig_path
    namespace       = var.namespace
    manifest        = local.flux_instance
  }

  provisioner "local-exec" {
    command = <<-EOT
      export KUBECONFIG="${var.kubeconfig_path}"
      cat <<'MANIFEST' | kubectl apply -f -
      ${local.flux_instance}
      MANIFEST
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      export KUBECONFIG="${self.triggers.kubeconfig_path}"
      kubectl delete fluxinstance flux -n ${self.triggers.namespace} --ignore-not-found=true
    EOT
  }

  depends_on = [time_sleep.wait_for_operator_crds]
}
