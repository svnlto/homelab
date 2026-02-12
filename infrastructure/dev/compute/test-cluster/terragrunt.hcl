# ==============================================================================
# Dev Test Cluster - Minimal Talos K8s for Testing
# ==============================================================================

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "provider" {
  path = "${get_terragrunt_dir()}/provider.hcl"
}

# Dependency on Talos image (must be uploaded first)
dependency "talos_image" {
  config_path = "../../images"
}

locals {
  global_vars = read_terragrunt_config(find_in_parent_folders("globals.hcl"))
  vlans       = local.global_vars.locals.vlans
  proxmox     = local.global_vars.locals.proxmox
  ips         = local.global_vars.locals.infrastructure_ips
}

inputs = {
  # Cluster Identity
  cluster_name     = "test"
  cluster_endpoint = "https://192.168.0.161:6443"

  # Versions (latest stable)
  talos_version      = "v1.12.2"
  kubernetes_version = "v1.35.0"

  # Talos Image (from persistent image storage)
  talos_image_id = dependency.talos_image.outputs.talos_image_id

  # Network - LAN VLAN 20 (migrate to vmbr32 when K8s VLANs are active)
  network_bridge  = "vmbr20"
  network_gateway = local.vlans.lan.gateway
  dns_servers     = [local.ips.pihole]
  vip_ip          = "192.168.0.160"

  # Proxmox
  proxmox_node_storage = "din"
  datastore_id         = "local-zfs"

  # Control Plane - Single node for dev (no HA needed)
  control_plane_nodes = {
    cp1 = {
      node_name    = "din"
      vm_id        = 310
      hostname     = "test-cp1"
      ip_address   = "192.168.0.161/24"
      cpu_cores    = 2
      memory_mb    = 4096
      disk_size_gb = 32
    }
  }

  # Workers - Single node for testing
  worker_nodes = {
    worker1 = {
      node_name       = "din"
      vm_id           = 320
      hostname        = "test-worker1"
      ip_address      = "192.168.0.162/24"
      cpu_cores       = 4
      memory_mb       = 8192
      disk_size_gb    = 100
      gpu_passthrough = false
    }
  }

  # Tags
  tags = ["dev"]

  # Bootstrap - Enable to start the cluster
  deploy_bootstrap = true
}
