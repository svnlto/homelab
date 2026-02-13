# ==============================================================================
# Jellyfin Media Server (VMID 210)
# ==============================================================================
# Target: grogu (r630) - Compute node with Intel Arc A310
# Purpose: NixOS VM running Jellyfin, Jellyseerr, jellyfin-auto-collections
# Network: vmbr20 on LAN VLAN 20
# GPU: Intel Arc A310 PCI passthrough for hardware transcoding
# Storage: 32GB boot disk, media/config via NFS from TrueNAS

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
  vm_id          = 210
  vm_name        = "jellyfin"
  vm_description = "NixOS - Jellyfin Media Server (Jellyfin, Jellyseerr, Intel Arc A310 GPU)"
  tags           = ["nixos", "jellyfin", "media", "production"]

  # Hardware
  cpu_cores         = 8
  memory_mb         = 8192
  boot_disk_size_gb = 32

  # Network - LAN VLAN 20
  network_bridge = "vmbr20"

  # Environment - Resource Pool
  pool_id = local.environments.prod.pools.compute

  # Boot - NixOS ISO (manual install, no cloud-init)
  iso_id = "local:iso/nixos-minimal-x86_64-linux.iso"

  # GPU Passthrough - Intel Arc A310 for hardware transcoding
  enable_pci_passthrough = true
  pci_mapping_id         = local.global_vars.locals.proxmox.resource_mappings.arc_a310

  # GPU passthrough requires vga=none (virtual VGA conflicts with Intel Arc)
  # Serial console provides Proxmox xterm.js access in place of noVNC
  vga_type              = "none"
  enable_serial_console = true
}
