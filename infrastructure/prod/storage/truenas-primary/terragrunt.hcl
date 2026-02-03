# ==============================================================================
# TrueNAS Primary Server (VMID 300)
# ==============================================================================
# Target: din (r730xd) - Primary storage node
# Storage: H330 Mini (5×8TB internal) + LSI 9201-8e (DS2246 shelf with 24×900GB)
# Network: Single interface on vmbr0
#
# HBA Passthrough: H330 Mini managed via Proxmox resource mapping "truenas-h330"
# Note: Additional HBAs (LSI 9201-8e) must be added manually via Proxmox UI

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "provider" {
  path = find_in_parent_folders("provider.hcl")
}

# Ensure resource pools and ISOs are created first
dependencies {
  paths = ["../../resource-pools", "../../iso-images"]
}

locals {
  global_vars  = read_terragrunt_config(find_in_parent_folders("globals.hcl"))
  truenas      = local.global_vars.locals.truenas
  ips          = local.global_vars.locals.infrastructure_ips
  environments = local.global_vars.locals.environments
  proxmox      = local.global_vars.locals.proxmox
}

inputs = {
  # Basic Configuration
  node_name      = local.truenas.primary.node_name
  vm_id          = local.truenas.primary.vm_id
  vm_name        = local.truenas.primary.hostname
  vm_description = "TrueNAS SCALE Primary Storage"
  tags           = ["truenas", "storage", "nas", "primary", "production"]

  # TrueNAS Configuration
  truenas_version = local.truenas.version
  iso_id          = "local:iso/${local.truenas.filename}"

  # Hardware
  cpu_cores         = local.truenas.primary.cores
  memory_mb         = local.truenas.primary.memory_mb
  boot_disk_size_gb = local.truenas.primary.disks.boot_size_gb

  # Network
  mac_address = "BC:24:11:2E:D4:03"

  # Environment - Resource Pool
  pool_id = local.environments.prod.pools.storage

  # HBA Passthrough - Dell H330 Mini (5×8TB internal drives)
  enable_hostpci  = true
  hostpci_mapping = local.proxmox.resource_mappings.truenas_h330
}
