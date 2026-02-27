data "talos_client_configuration" "talosconfig" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.cluster.client_configuration
  endpoints            = [for node in values(var.control_plane_nodes) : split("/", node.ip_address)[0]]
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
              vip = {
                ip = var.vip_ip
              }
            }
          ]
          nameservers = var.dns_servers
        }
        time = {
          servers = var.ntp_servers
        }
        install = {
          disk  = "/dev/sda"
          image = "factory.talos.dev/nocloud-installer/${var.talos_schematic_id}:${var.talos_version}"
        }
        sysctls = {
          "net.ipv6.conf.all.disable_ipv6"     = "1"
          "net.ipv6.conf.default.disable_ipv6" = "1"
          "net.ipv6.conf.lo.disable_ipv6"      = "1"
        }
        features = {
          kubernetesTalosAPIAccess = {
            enabled                     = true
            allowedRoles                = ["os:reader"]
            allowedKubernetesNamespaces = ["kube-system"]
          }
        }
        registries = length(var.registry_mirrors) > 0 ? {
          mirrors = {
            for name, mirror in var.registry_mirrors : name => {
              endpoints = [mirror.endpoint]
            }
          }
        } : null
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
        scheduler = {
          config = {
            apiVersion = "kubescheduler.config.k8s.io/v1"
            kind       = "KubeSchedulerConfiguration"
            profiles = [
              {
                schedulerName = "default-scheduler"
                pluginConfig = [
                  {
                    name = "PodTopologySpread"
                    args = {
                      defaultingType = "List"
                      defaultConstraints = [
                        {
                          maxSkew           = 1
                          topologyKey       = "kubernetes.io/hostname"
                          whenUnsatisfiable = "ScheduleAnyway"
                        }
                      ]
                    }
                  }
                ]
              }
            ]
          }
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
        time = {
          servers = var.ntp_servers
        }
        install = {
          disk  = "/dev/sda"
          image = "factory.talos.dev/nocloud-installer/${each.value.gpu_passthrough && var.talos_gpu_schematic_id != "" ? var.talos_gpu_schematic_id : var.talos_schematic_id}:${var.talos_version}"
        }
        kernel = each.value.gpu_passthrough ? {
          modules = [
            {
              name = "xe"
            }
          ]
        } : {}
        sysctls = {
          "net.ipv6.conf.all.disable_ipv6"     = "1"
          "net.ipv6.conf.default.disable_ipv6" = "1"
          "net.ipv6.conf.lo.disable_ipv6"      = "1"
        }
        registries = length(var.registry_mirrors) > 0 ? {
          mirrors = {
            for name, mirror in var.registry_mirrors : name => {
              endpoints = [mirror.endpoint]
            }
          }
        } : null
      }
    })
  ]
}
