# ==============================================================================
# TrueNAS Primary Server (VMID 300)
# ==============================================================================
# Target: din (r730xd) - Primary storage node
# Storage: H330 Mini (6×8TB bulk) + MD1220 (6×3TB scratch) + PERC H200E (24×900GB fast)
# Network: Dual-homed (VLAN 10 storage + VLAN 20 management)
#
# HBA Passthrough: H330 Mini via resource mapping "truenas-h330" (hostpci0)
# PERC H200E via resource mapping "truenas-lsi" (hostpci1, added manually in Proxmox UI)

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "provider" {
  path = find_in_parent_folders("provider.hcl")
}

# Ensure resource pools and images are created first
dependencies {
  paths = ["../../resource-pools", "../../images"]
}

locals {
  global_vars  = read_terragrunt_config(find_in_parent_folders("globals.hcl"))
  truenas      = local.global_vars.locals.truenas
  ips          = local.global_vars.locals.infrastructure_ips
  vlans        = local.global_vars.locals.vlans
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

  # Dual Network Configuration
  enable_dual_network = true
  mac_address         = "BC:24:11:2E:D4:03"
  storage_bridge      = local.proxmox.bridges.storage

  # Environment - Resource Pool
  pool_id = local.environments.prod.pools.storage

  # Cloud-init Network Configuration
  enable_network_init = true
  management_ip       = "${local.ips.truenas_primary_mgmt}/24"
  management_gateway  = local.vlans.lan.gateway
  storage_ip          = "${local.ips.truenas_primary_storage}/24"
  dns_server          = local.ips.pihole

  # HBA Passthrough - Dell H330 Mini (6×8TB bulk drives)
  enable_hostpci  = true
  hostpci_mapping = local.proxmox.resource_mappings.truenas_h330
}
