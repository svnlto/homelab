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
  proxmox      = local.global_vars.locals.proxmox
  vm_ids       = local.global_vars.locals.vm_ids
  environments = local.global_vars.locals.environments
}

inputs = {
  node_name      = local.proxmox.nodes.primary
  vm_id          = local.vm_ids.arr_stack
  vm_name        = "arr-stack"
  vm_description = "NixOS - Arr Media Stack (Sonarr, Radarr, Prowlarr, qBittorrent, SABnzbd)"
  tags           = ["nixos", "arr", "media", "production"]

  cpu_cores         = 8
  memory_mb         = 6144
  boot_disk_size_gb = 32

  network_bridge      = local.proxmox.bridges.lan
  enable_dual_network = true
  secondary_bridge    = local.proxmox.bridges.storage

  pool_id = local.environments.prod.pools.compute

  iso_id = "local:iso/nixos-minimal-x86_64-linux.iso"
}
