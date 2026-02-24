# ==============================================================================
# External Secrets Operator - 1Password SDK Backend
# ==============================================================================

resource "kubernetes_namespace_v1" "external_secrets" {
  count = var.deploy_bootstrap && var.external_secrets_enabled ? 1 : 0

  metadata {
    name = "external-secrets"
  }

  depends_on = [data.talos_cluster_health.cluster]
}

resource "kubernetes_secret_v1" "onepassword_sa_token" {
  count = var.deploy_bootstrap && var.external_secrets_enabled ? 1 : 0

  metadata {
    name      = "onepassword-sa-token"
    namespace = kubernetes_namespace_v1.external_secrets[0].metadata[0].name
  }

  data = {
    token = var.op_service_account_token
  }

  type = "Opaque"
}

resource "helm_release" "external_secrets" {
  count = var.deploy_bootstrap && var.external_secrets_enabled ? 1 : 0

  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = "0.14.3"
  namespace        = kubernetes_namespace_v1.external_secrets[0].metadata[0].name
  create_namespace = false
  wait             = true
  timeout          = 300

  values = [yamlencode({
    installCRDs = true
    resources = {
      requests = { cpu = "25m", memory = "64Mi" }
      limits   = { memory = "256Mi" }
    }
    webhook = {
      resources = {
        requests = { cpu = "10m", memory = "32Mi" }
        limits   = { memory = "128Mi" }
      }
    }
    certController = {
      resources = {
        requests = { cpu = "10m", memory = "32Mi" }
        limits   = { memory = "128Mi" }
      }
    }
  })]

  depends_on = [data.talos_cluster_health.cluster]
}

resource "kubectl_manifest" "cluster_secret_store" {
  count = var.deploy_bootstrap && var.external_secrets_enabled ? 1 : 0

  validate_schema = false

  yaml_body = <<-YAML
    apiVersion: external-secrets.io/v1beta1
    kind: ClusterSecretStore
    metadata:
      name: onepassword
    spec:
      provider:
        onepassword:
          connectHost: ""
          vaults:
            ${var.op_vault_name}: 1
          auth:
            secretRef:
              connectTokenSecretRef:
                name: onepassword-sa-token
                namespace: external-secrets
                key: token
  YAML

  depends_on = [helm_release.external_secrets]
}
