# Dev test cluster — minimal Talos K8s on LAN VLAN 20.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "provider" {
  path = "${get_terragrunt_dir()}/provider.hcl"
}

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
  cluster_name     = "test"
  cluster_endpoint = "https://192.168.0.161:6443"

  talos_version      = "v1.12.2"
  kubernetes_version = "v1.35.0"
  talos_image_id     = dependency.talos_image.outputs.talos_image_id

  network_bridge  = "vmbr20"
  network_gateway = local.vlans.lan.gateway
  dns_servers     = [local.ips.pihole]
  vip_ip          = "192.168.0.160"

  datastore_id = "local-zfs"

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

  tags             = ["dev"]
  deploy_bootstrap = true
}
