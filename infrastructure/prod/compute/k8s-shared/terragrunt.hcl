# Shared services Talos K8s cluster — VLAN 30 (10.0.1.0/24).

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "provider" {
  path = "${get_terragrunt_dir()}/provider.hcl"
}

dependency "images" {
  config_path = "../../images"

  mock_outputs = {
    talos_image_id_din = "local:iso/talos-mock-nocloud.img"
  }
  mock_outputs_merge_strategy_with_state = "shallow"
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "tailscale" {
  config_path = "../../tailscale/acl"

  mock_outputs = {
    k8s_oauth_client_id     = "mock-client-id"
    k8s_oauth_client_secret = "mock-client-secret"
  }
  mock_outputs_merge_strategy_with_state = "shallow"
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

locals {
  global_vars = read_terragrunt_config(find_in_parent_folders("globals.hcl"))
  vlans       = local.global_vars.locals.vlans
  proxmox     = local.global_vars.locals.proxmox
  ips         = local.global_vars.locals.infrastructure_ips
  k8s         = local.global_vars.locals.k8s_clusters.shared
}

inputs = {
  cluster_name     = "shared"
  cluster_endpoint = "https://${local.k8s.vip}:6443"

  talos_version      = "v1.12.2"
  kubernetes_version = "v1.35.0"
  talos_image_id     = dependency.images.outputs.talos_image_id_din

  network_bridge  = local.proxmox.bridges.k8s_shared
  network_gateway = local.vlans.k8s_shared.gateway
  dns_servers     = [local.ips.pihole]
  vip_ip          = local.k8s.vip

  datastore_id = "local-zfs"

  control_plane_nodes = {
    cp1 = {
      node_name    = "din"
      vm_id        = 400
      hostname     = "shared-cp1"
      ip_address   = "${local.k8s.control_start}/24"
      cpu_cores    = 4
      memory_mb    = 4096
      disk_size_gb = 50
    }
    cp2 = {
      node_name    = "din"
      vm_id        = 401
      hostname     = "shared-cp2"
      ip_address   = "10.0.1.12/24"
      cpu_cores    = 4
      memory_mb    = 4096
      disk_size_gb = 50
    }
    cp3 = {
      node_name    = "grogu"
      vm_id        = 402
      hostname     = "shared-cp3"
      ip_address   = "10.0.1.13/24"
      cpu_cores    = 4
      memory_mb    = 4096
      disk_size_gb = 50
    }
  }

  worker_nodes = {
    worker1 = {
      node_name       = "din"
      vm_id           = 410
      hostname        = "shared-worker1"
      ip_address      = "${local.k8s.worker_start}/24"
      cpu_cores       = 4
      memory_mb       = 16384
      disk_size_gb    = 100
      gpu_passthrough = false
    }
    worker2 = {
      node_name       = "grogu"
      vm_id           = 411
      hostname        = "shared-worker2"
      ip_address      = "10.0.1.22/24"
      cpu_cores       = 4
      memory_mb       = 16384
      disk_size_gb    = 100
      gpu_passthrough = false
    }
  }

  tags             = ["production", "k8s", "shared"]
  deploy_bootstrap = true

  # Democratic-CSI — TrueNAS primary (storage VLAN)
  truenas_api_url     = "https://${local.ips.truenas_primary_storage}"
  truenas_api_key     = get_env("TF_VAR_truenas_api_key", "")
  truenas_nfs_dataset = "bulk/kubernetes/nfs-dynamic"

  # iSCSI deferred — will configure when fast pool is available
  truenas_iscsi_portal = ""

  # MetalLB
  metallb_ip_range = "${local.k8s.metallb_start}-${local.k8s.metallb_end}"

  # Traefik
  traefik_enabled = true

  # Tailscale (OAuth client created by prod/tailscale/acl module)
  tailscale_enabled             = true
  tailscale_oauth_client_id     = dependency.tailscale.outputs.k8s_oauth_client_id
  tailscale_oauth_client_secret = dependency.tailscale.outputs.k8s_oauth_client_secret
  tailscale_hostname            = local.k8s.tailscale_hostname

  # Traefik ACME (staging first — switch to production when verified)
  traefik_acme_enabled  = true
  traefik_acme_email    = get_env("TF_VAR_acme_email", "")
  traefik_acme_server   = "https://acme-staging-v02.api.letsencrypt.org/directory"
  cloudns_auth_id       = get_env("TF_VAR_cloudns_auth_id", "")
  cloudns_auth_password = get_env("TF_VAR_cloudns_auth_password", "")
}
