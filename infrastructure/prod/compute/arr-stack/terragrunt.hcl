# Arr media stack (VMID 200) on din — Sonarr, Radarr, Prowlarr, qBittorrent, SABnzbd.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "provider" {
  path = find_in_parent_folders("provider.hcl")
}

dependencies {
  paths = ["../../resource-pools"]
}

locals {
  global_vars  = read_terragrunt_config(find_in_parent_folders("globals.hcl"))
  ips          = local.global_vars.locals.infrastructure_ips
  environments = local.global_vars.locals.environments
}

inputs = {
  node_name      = "din"
  vm_id          = 200
  vm_name        = "arr-stack"
  vm_description = "NixOS - Arr Media Stack (Sonarr, Radarr, Prowlarr, qBittorrent, SABnzbd)"
  tags           = ["nixos", "arr", "media", "production"]

  cpu_cores         = 8
  memory_mb         = 6144
  boot_disk_size_gb = 32

  network_bridge      = "vmbr20"
  enable_dual_network = true
  secondary_bridge    = "vmbr10"

  pool_id = local.environments.prod.pools.compute

  iso_id = "local:iso/nixos-minimal-x86_64-linux.iso"
}
