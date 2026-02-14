# TrueNAS Primary (VMID 300) on din — H330 Mini passthrough, second HBA added manually in UI.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "provider" {
  path = find_in_parent_folders("provider.hcl")
}

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
  node_name      = local.truenas.primary.node_name
  vm_id          = local.truenas.primary.vm_id
  vm_name        = local.truenas.primary.hostname
  vm_description = "TrueNAS SCALE Primary Storage"
  tags           = ["truenas", "storage", "nas", "primary", "production"]

  truenas_version = local.truenas.version
  iso_id          = "local:iso/${local.truenas.filename}"

  cpu_cores         = local.truenas.primary.cores
  memory_mb         = local.truenas.primary.memory_mb
  boot_disk_size_gb = local.truenas.primary.disks.boot_size_gb

  enable_dual_network = true
  mac_address         = "BC:24:11:2E:D4:03"
  storage_bridge      = local.proxmox.bridges.storage

  pool_id = local.environments.prod.pools.storage

  enable_network_init = true
  management_ip       = "${local.ips.truenas_primary_mgmt}/24"
  management_gateway  = local.vlans.lan.gateway
  storage_ip          = "${local.ips.truenas_primary_storage}/24"
  dns_server          = local.ips.pihole

  enable_hostpci  = true
  hostpci_mapping = local.proxmox.resource_mappings.truenas_h330
}
