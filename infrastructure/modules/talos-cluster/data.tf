data "talos_client_configuration" "talosconfig" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.cluster.client_configuration
  endpoints            = [split("/", values(var.control_plane_nodes)[0].ip_address)[0]]
}

# ==============================================================================
# Talos Machine Configurations
# ==============================================================================

data "talos_machine_configuration" "control_plane" {
  for_each = var.control_plane_nodes

  cluster_name       = var.cluster_name
  cluster_endpoint   = var.cluster_endpoint
  machine_type       = "controlplane"
  machine_secrets    = talos_machine_secrets.cluster.machine_secrets
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version

  config_patches = [
    yamlencode({
      machine = {
        network = {
          interfaces = [
            {
              interface = "eth0"
              addresses = [each.value.ip_address]
              routes = [
                {
                  network = "0.0.0.0/0"
                  gateway = var.network_gateway
                }
              ]
            }
          ]
          nameservers = var.dns_servers
        }
        install = {
          disk  = "/dev/sda"
          image = "factory.talos.dev/nocloud-installer/dc7b152cb3ea99b821fcb7340ce7168313ce393d663740b791c36f6e95fc8586:${var.talos_version}"
        }
        features = {
          kubernetesTalosAPIAccess = {
            enabled                     = true
            allowedRoles                = ["os:reader"]
            allowedKubernetesNamespaces = ["kube-system"]
          }
        }
      }
      cluster = {
        network = {
          cni = {
            name = "none"
          }
        }
        discovery = {
          enabled = true
        }
        inlineManifests = var.deploy_bootstrap ? [
          {
            name     = "cilium"
            contents = data.helm_template.cilium[0].manifest
          }
        ] : []
      }
    })
  ]
}


data "talos_machine_configuration" "worker" {
  for_each = var.worker_nodes

  cluster_name       = var.cluster_name
  cluster_endpoint   = var.cluster_endpoint
  machine_type       = "worker"
  machine_secrets    = talos_machine_secrets.cluster.machine_secrets
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version

  config_patches = [
    yamlencode({
      machine = {
        network = {
          interfaces = [
            {
              interface = "eth0"
              addresses = [each.value.ip_address]
              routes = [
                {
                  network = "0.0.0.0/0"
                  gateway = var.network_gateway
                }
              ]
            }
          ]
          nameservers = var.dns_servers
        }
        install = {
          disk  = "/dev/sda"
          image = "factory.talos.dev/nocloud-installer/dc7b152cb3ea99b821fcb7340ce7168313ce393d663740b791c36f6e95fc8586:${var.talos_version}"
        }
        sysctls = each.value.gpu_passthrough ? {
          "kernel.modules_disabled" = "0"
        } : {}
      }
    })
  ]
}
