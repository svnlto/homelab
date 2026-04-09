# ==============================================================================
# Flux Operator Module — GitOps via FluxCD
# ==============================================================================
# Deploys Flux Operator + FluxInstance on the cluster.
# FluxInstance syncs from a Git repository using the Kustomize controller.

# ==============================================================================
# Kubernetes Provider Configuration
# ==============================================================================

provider "kubernetes" {
  config_path = var.kubeconfig_path
}

provider "helm" {
  kubernetes = {
    config_path = var.kubeconfig_path
  }
}

# ==============================================================================
# Flux System Namespace
# ==============================================================================

resource "kubernetes_namespace_v1" "flux_system" {
  metadata {
    name = var.namespace
  }
}

# ==============================================================================
# Git Credentials Secret
# ==============================================================================
# Used by source-controller for repo access and image-automation-controller
# for pushing image tag updates back to the repository.

resource "kubernetes_secret_v1" "git_credentials" {
  metadata {
    name      = "flux-system"
    namespace = kubernetes_namespace_v1.flux_system.metadata[0].name
  }

  data = {
    username = "git"
    password = var.github_token
  }

  type = "Opaque"
}

# ==============================================================================
# Flux Operator Helm Chart
# ==============================================================================
# Installs the operator that manages FluxInstance CRDs and the web UI.

resource "helm_release" "flux_operator" {
  name       = "flux-operator"
  repository = "oci://ghcr.io/controlplaneio-fluxcd/charts"
  chart      = "flux-operator"
  version    = var.flux_operator_version
  namespace  = kubernetes_namespace_v1.flux_system.metadata[0].name

  depends_on = [kubernetes_namespace_v1.flux_system]
}

# Wait for operator CRDs to register before creating FluxInstance
resource "time_sleep" "wait_for_operator" {
  depends_on = [helm_release.flux_operator]

  create_duration = "30s"
}

# ==============================================================================
# Flux Instance Helm Chart
# ==============================================================================
# Creates the FluxInstance CR that bootstraps all Flux controllers and
# configures the Git sync entry point.

resource "helm_release" "flux_instance" {
  name       = "flux"
  repository = "oci://ghcr.io/controlplaneio-fluxcd/charts"
  chart      = "flux-instance"
  version    = var.flux_instance_version
  namespace  = kubernetes_namespace_v1.flux_system.metadata[0].name

  values = [yamlencode({
    instance = {
      distribution = {
        version  = "2.x"
        registry = "ghcr.io/fluxcd"
      }

      cluster = {
        type = "kubernetes"
        size = "small"
      }

      components = [
        "source-controller",
        "kustomize-controller",
        "helm-controller",
        "notification-controller",
        "image-reflector-controller",
        "image-automation-controller",
      ]

      sync = {
        kind       = "GitRepository"
        url        = var.repo_url
        ref        = "refs/heads/${var.repo_branch}"
        path       = var.sync_path
        pullSecret = kubernetes_secret_v1.git_credentials.metadata[0].name
      }
    }
  })]

  depends_on = [time_sleep.wait_for_operator]
}

# ==============================================================================
# Flux Web UI Ingress (Traefik)
# ==============================================================================
# Exposes the Flux Operator status page via Traefik ingress.

resource "kubernetes_ingress_v1" "flux_ui" {
  count = var.ingress_host != "" ? 1 : 0

  metadata {
    name      = "flux-operator-ui"
    namespace = kubernetes_namespace_v1.flux_system.metadata[0].name
    annotations = {
      "traefik.ingress.kubernetes.io/router.entrypoints" = "websecure"
      "traefik.ingress.kubernetes.io/router.tls"         = "true"
    }
  }

  spec {
    ingress_class_name = "traefik"

    rule {
      host = var.ingress_host

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "flux-operator"
              port {
                number = 9080
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.flux_operator]
}
