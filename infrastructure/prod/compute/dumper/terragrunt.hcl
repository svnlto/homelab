# ==============================================================================
# Dumper VM (VMID 202)
# ==============================================================================
# Target: grogu (r630) - NixOS VM for Tailscale rsync automation
# Purpose: Persistent Tailscale + daily rsync from remote machine to TrueNAS
# Network: vmbr20 (LAN VLAN 20) + vmbr10 (Storage VLAN 10)
# Storage: 8GB boot disk, NFS mount to TrueNAS scratch pool

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
  node_name      = "grogu"
  vm_id          = 202
  vm_name        = "dumper"
  vm_description = "NixOS - Tailscale rsync automation (photo dump to TrueNAS)"
  tags           = ["nixos", "tailscale", "rsync", "production"]

  # Hardware
  cpu_cores         = 2
  memory_mb         = 2048
  boot_disk_size_gb = 8

  # Network - LAN VLAN 20 + Storage VLAN 10
  network_bridge      = "vmbr20"
  enable_dual_network = true
  secondary_bridge    = "vmbr10"

  # Environment - Resource Pool
  pool_id = local.environments.prod.pools.compute

  # Boot - NixOS ISO (manual install, no cloud-init)
  iso_id = "local:iso/nixos-minimal-x86_64-linux.iso"
}
