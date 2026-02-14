# TrueNAS Backup (VMID 301) on grogu — MD1200 HBA passthrough added manually in Proxmox UI.

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
  node_name      = local.truenas.backup.node_name
  vm_id          = local.truenas.backup.vm_id
  vm_name        = local.truenas.backup.hostname
  vm_description = "TrueNAS SCALE Backup Storage"
  tags           = ["truenas", "storage", "nas", "backup", "production"]

  truenas_version = local.truenas.version
  iso_id          = "local:iso/${local.truenas.filename}"

  cpu_cores         = local.truenas.backup.cores
  memory_mb         = local.truenas.backup.memory_mb
  boot_disk_size_gb = local.truenas.backup.disks.boot_size_gb

  enable_dual_network = true
  mac_address         = "BC:24:11:2E:D4:04"
  storage_bridge      = local.proxmox.bridges.storage

  pool_id = local.environments.prod.pools.storage

  enable_network_init = true
  management_ip       = "${local.ips.truenas_backup_mgmt}/24"
  management_gateway  = local.vlans.lan.gateway
  storage_ip          = "${local.ips.truenas_backup_storage}/24"
  dns_server          = local.ips.pihole
}
