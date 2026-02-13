# ==============================================================================
# Dumper LXC Container (VMID 202)
# ==============================================================================
# Target: grogu (r630) - NixOS LXC for Tailscale rsync automation
# Purpose: Persistent Tailscale + daily rsync from remote machine to TrueNAS
# Network: vmbr20 (LAN VLAN 20) + vmbr10 (Storage VLAN 10)
# Storage: 2GB rootfs, NFS mount to TrueNAS scratch pool

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "provider" {
  path = find_in_parent_folders("provider.hcl")
}

# Ensure resource pools are created first
dependencies {
  paths = ["../../resource-pools"]
}

locals {
  global_vars  = read_terragrunt_config(find_in_parent_folders("globals.hcl"))
  ips          = local.global_vars.locals.infrastructure_ips
  environments = local.global_vars.locals.environments
}

inputs = {
  # Basic Configuration
  node_name             = "grogu"
  container_id          = 202
  container_name        = "dumper"
  container_description = "NixOS LXC - Tailscale rsync automation (photo dump to TrueNAS)"
  tags                  = ["nixos", "tailscale", "rsync", "production"]

  # Hardware
  cores       = 1
  memory_mb   = 512
  disk_size_gb = 2

  # Network - LAN VLAN 20 + Storage VLAN 10
  network_bridge   = "vmbr20"
  secondary_bridge = "vmbr10"

  # Initialization
  ip_address  = "${local.ips.dumper}/24"
  gateway     = local.ips.router_lan
  storage_ip  = "${local.ips.dumper_storage}/24"
  dns_servers = [local.ips.pihole]

  # Template
  template_file_id = "local:vztmpl/nixos-lxc.tar.xz"

  # Environment - Resource Pool
  pool_id = local.environments.prod.pools.compute
}
