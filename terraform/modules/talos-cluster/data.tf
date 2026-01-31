data "talos_client_configuration" "talosconfig" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.cluster.client_configuration
  endpoints            = [split("/", values(var.control_plane_nodes)[0].ip_address)[0]]
}

data "talos_image_factory_extensions_versions" "this" {
  talos_version = var.talos_version
  filters = {
    names = var.talos_extensions
  }
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
          hostname = each.value.hostname
          interfaces = [{
            interface = "eth0"
            addresses = [each.value.ip_address]
            routes = [{
              network = "0.0.0.0/0"
              gateway = var.network_gateway
            }]
            vip = {
              ip = var.vip_ip
            }
          }]
          nameservers = var.dns_servers
        }
        install = {
          disk  = "/dev/sda"
          image = "factory.talos.dev/installer/${talos_image_factory_schematic.this.id}:${var.talos_version}"
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
          hostname = each.value.hostname
          interfaces = [{
            interface = "eth0"
            addresses = [each.value.ip_address]
            routes = [{
              network = "0.0.0.0/0"
              gateway = var.network_gateway
            }]
          }]
          nameservers = var.dns_servers
        }
        install = {
          disk  = "/dev/sda"
          image = "factory.talos.dev/installer/${talos_image_factory_schematic.this.id}:${var.talos_version}"
        }
        sysctls = each.value.gpu_passthrough ? {
          "kernel.modules_disabled" = "0"
        } : {}
      }
    })
  ]
}
