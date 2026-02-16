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

resource "kubernetes_secret_v1" "traefik_cloudns" {
  count = var.deploy_bootstrap && var.traefik_enabled && var.traefik_acme_enabled ? 1 : 0

  metadata {
    name      = "traefik-cloudns-credentials"
    namespace = kubernetes_namespace_v1.traefik[0].metadata[0].name
  }

  data = {
    auth_id       = var.cloudns_auth_id
    auth_password = var.cloudns_auth_password
  }
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

  # Base values
  values = [
    yamlencode({
      service = merge(
        { type = "LoadBalancer" },
        var.tailscale_enabled ? {
          additionalServices = {
            tailscale = {
              type              = "LoadBalancer"
              loadBalancerClass = "tailscale"
              annotations = {
                "tailscale.com/hostname" = var.tailscale_hostname
              }
            }
          }
        } : {}
      )
      ports = {
        web = merge(
          {
            port        = 8000
            exposedPort = 80
          },
          var.tailscale_enabled ? {
            expose = {
              default   = true
              tailscale = true
            }
          } : {}
        )
        websecure = merge(
          {
            port        = 8443
            exposedPort = 443
          },
          var.tailscale_enabled ? {
            expose = {
              default   = true
              tailscale = true
            }
          } : {}
        )
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
      serversTransport = {
        insecureSkipVerify = true
      }
    }),
    # ACME + ClouDNS + persistence (separate yamlencode to avoid type mismatch)
    var.traefik_acme_enabled ? yamlencode({
      certificatesResolvers = {
        letsencrypt = {
          acme = {
            email    = var.traefik_acme_email
            caServer = var.traefik_acme_server
            storage  = "/data/acme.json"
            dnsChallenge = {
              provider  = "cloudns"
              resolvers = ["1.1.1.1:53", "8.8.8.8:53"]
            }
          }
        }
      }
      env = [
        {
          name = "CLOUDNS_AUTH_ID"
          valueFrom = {
            secretKeyRef = {
              name = "traefik-cloudns-credentials"
              key  = "auth_id"
            }
          }
        },
        {
          name = "CLOUDNS_AUTH_PASSWORD"
          valueFrom = {
            secretKeyRef = {
              name = "traefik-cloudns-credentials"
              key  = "auth_password"
            }
          }
        }
      ]
      persistence = {
        enabled      = true
        storageClass = "truenas-nfs-rwx"
        accessMode   = "ReadWriteOnce"
        size         = "128Mi"
      }
    }) : yamlencode({}),
  ]

  depends_on = [
    helm_release.metallb,
    helm_release.tailscale_operator,
  ]
}

data "kubernetes_service_v1" "traefik_tailscale" {
  count = var.deploy_bootstrap && var.traefik_enabled && var.tailscale_enabled ? 1 : 0

  metadata {
    name      = "traefik-tailscale"
    namespace = "traefik"
  }

  depends_on = [helm_release.traefik]
}
