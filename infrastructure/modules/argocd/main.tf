# ==============================================================================
# ArgoCD Module - Hub-and-Spoke GitOps
# ==============================================================================
# Deploys ArgoCD on hub cluster to manage applications across all clusters
# Uses App of Apps pattern with Kustomize overlays

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
# ArgoCD Namespace
# ==============================================================================

resource "kubernetes_namespace_v1" "argocd" {
  metadata {
    name = var.argocd_namespace
  }
}

# ==============================================================================
# ArgoCD Helm Chart
# ==============================================================================

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version
  namespace  = kubernetes_namespace_v1.argocd.metadata[0].name

  # Set initial admin password
  set_sensitive = [
    {
      name  = "configs.secret.argocdServerAdminPassword"
      value = bcrypt(var.admin_password)
    }
  ]

  # Server configuration
  values = [yamlencode({
    server = {
      # Enable ingress if configured
      ingress = {
        enabled = var.ingress_enabled
        hosts   = var.ingress_enabled ? [var.ingress_host] : []
      }

      # Metrics for monitoring
      metrics = {
        enabled = true
      }

      # Git repository configuration
      config = {
        repositories = <<-EOT
          - url: ${var.repo_url}
            name: homelab
        EOT
      }
    }

    # Controller settings
    controller = {
      metrics = {
        enabled = true
      }
    }

    # Repo server settings
    repoServer = {
      metrics = {
        enabled = true
      }
    }

    # Application controller
    applicationSet = {
      enabled = true
    }

    # Notifications controller
    notifications = {
      enabled = true
    }
  })]

  depends_on = [kubernetes_namespace_v1.argocd]
}

# ==============================================================================
# Root Application (App of Apps)
# ==============================================================================

# Wait for ArgoCD to be ready and CRDs registered
resource "time_sleep" "wait_for_argocd_crds" {
  depends_on = [helm_release.argocd]

  create_duration = "60s"
}

# Create root Application via kubectl apply (avoids CRD validation during plan)
resource "null_resource" "root_app" {
  triggers = {
    kubeconfig_path = var.kubeconfig_path
    repo_url        = var.repo_url
    repo_branch     = var.repo_branch
    root_app_path   = var.root_app_path
  }

  provisioner "local-exec" {
    command = <<-EOT
      export KUBECONFIG="${var.kubeconfig_path}"
      cat <<EOF | kubectl apply -f -
      apiVersion: argoproj.io/v1alpha1
      kind: Application
      metadata:
        name: root
        namespace: ${var.argocd_namespace}
        finalizers:
          - resources-finalizer.argocd.argoproj.io
      spec:
        project: default
        source:
          repoURL: ${var.repo_url}
          targetRevision: ${var.repo_branch}
          path: ${var.root_app_path}
          directory:
            recurse: true
        destination:
          server: https://kubernetes.default.svc
          namespace: ${var.argocd_namespace}
        syncPolicy:
          automated:
            prune: true
            selfHeal: true
          syncOptions:
            - CreateNamespace=true
      EOF
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      export KUBECONFIG="${self.triggers.kubeconfig_path}"
      kubectl delete application root -n argocd --ignore-not-found=true
    EOT
  }

  depends_on = [time_sleep.wait_for_argocd_crds]
}

# ==============================================================================
# Spoke Cluster Registration
# ==============================================================================

resource "kubernetes_secret_v1" "spoke_clusters" {
  for_each = var.spoke_clusters

  metadata {
    name      = "${each.key}-cluster"
    namespace = var.argocd_namespace
    labels = {
      "argocd.argoproj.io/secret-type" = "cluster"
    }
  }

  data = {
    name   = each.key
    server = each.value.server
    config = jsonencode({
      tlsClientConfig = {
        insecure = false
        caData   = each.value.ca_data
        certData = each.value.cert_data
        keyData  = each.value.key_data
      }
    })
  }

  type = "Opaque"

  depends_on = [helm_release.argocd]
}
