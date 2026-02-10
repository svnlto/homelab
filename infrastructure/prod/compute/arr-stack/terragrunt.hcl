# ==============================================================================
# Arr Media Stack (VMID 200)
# ==============================================================================
# Target: din (r730xd) - Primary compute node
# Purpose: NixOS VM running arr media stack (Sonarr, Radarr, etc.)
# Network: vmbr0 on LAN (no VLAN tag until MikroTik switch)
# Storage: 32GB boot disk, media/downloads via NFS from TrueNAS

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
  node_name      = "din"
  vm_id          = 200
  vm_name        = "arr-stack"
  vm_description = "NixOS - Arr Media Stack (Sonarr, Radarr, Prowlarr, qBittorrent, SABnzbd)"
  tags           = ["nixos", "arr", "media", "production"]

  # Hardware
  cpu_cores         = 4
  memory_mb         = 6144
  boot_disk_size_gb = 32

  # Network - LAN on vmbr0 (no VLAN tag)
  network_bridge = "vmbr0"

  # Environment - Resource Pool
  pool_id = local.environments.prod.pools.compute

  # Boot - NixOS ISO (manual install, no cloud-init)
  iso_id = "local:iso/nixos-minimal-x86_64-linux.iso"
}
