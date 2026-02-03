# ==============================================================================
# TrueNAS Backup Server (VMID 301)
# ==============================================================================
# Target: grogu (r630) - Backup storage node
# Storage: MD1200 disk shelf (8×3TB via HBA passthrough)
# Network: Dual-homed (VLAN 10 storage + VLAN 20 management)
#
# Note: MD1200 HBA passthrough must be configured manually in Proxmox UI
# due to provider limitations. This creates the VM shell.

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
  vlans        = local.global_vars.locals.vlans
  environments = local.global_vars.locals.environments
}

inputs = {
  # Basic Configuration
  node_name      = local.truenas.backup.node_name
  vm_id          = local.truenas.backup.vm_id
  vm_name        = local.truenas.backup.hostname
  vm_description = "TrueNAS SCALE Backup Storage"
  tags           = ["truenas", "storage", "nas", "backup", "production"]

  # TrueNAS Configuration
  truenas_version = local.truenas.version
  iso_id          = "local:iso/${local.truenas.filename}"

  # Hardware
  cpu_cores         = local.truenas.backup.cores
  memory_mb         = local.truenas.backup.memory_mb
  boot_disk_size_gb = local.truenas.backup.disks.boot_size_gb

  # Dual Network Configuration
  enable_dual_network = true
  mac_address         = "BC:24:11:2E:D4:04"
  vlan_id             = local.vlans.lan.id
  storage_vlan_id     = local.vlans.storage.id

  # Environment - Resource Pool
  pool_id = local.environments.prod.pools.storage

  # Cloud-init Network Configuration
  enable_network_init = true
  management_ip       = "${local.ips.truenas_backup_mgmt}/24"
  management_gateway  = local.ips.gateway
  storage_ip          = "${local.ips.truenas_backup_storage}/24"
  dns_server          = local.ips.pihole
}
