# Jellyfin (VMID 210) on grogu — Intel Arc A310 GPU passthrough for hardware transcoding.

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
  node_name      = local.proxmox.nodes.secondary
  vm_id          = local.vm_ids.jellyfin
  vm_name        = "jellyfin"
  vm_description = "NixOS - Jellyfin Media Server (Jellyfin, Jellyseerr, Intel Arc A310 GPU)"
  tags           = ["nixos", "jellyfin", "media", "production"]

  cpu_cores         = 8
  memory_mb         = 8192
  boot_disk_size_gb = 32

  network_bridge      = local.proxmox.bridges.lan
  enable_dual_network = true
  secondary_bridge    = local.proxmox.bridges.storage

  pool_id = local.environments.prod.pools.compute

  iso_id = "local:iso/nixos-minimal-x86_64-linux.iso"

  enable_pci_passthrough = true
  pci_mapping_id         = local.proxmox.resource_mappings.arc_a310

  # vga=none required for GPU passthrough; serial console for xterm.js access
  vga_type              = "none"
  enable_serial_console = true
}
