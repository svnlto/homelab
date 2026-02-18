# Proxmox Backup Server (VMID 220) on grogu — VM backups to TrueNAS NFS.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "provider" {
  path = find_in_parent_folders("provider.hcl")
}

dependencies {
  paths = ["../../images", "../../resource-pools"]
}

locals {
  global_vars  = read_terragrunt_config(find_in_parent_folders("globals.hcl"))
  proxmox      = local.global_vars.locals.proxmox
  vm_ids       = local.global_vars.locals.vm_ids
  environments = local.global_vars.locals.environments
  pbs          = local.global_vars.locals.pbs
}

inputs = {
  node_name      = local.proxmox.nodes.secondary
  vm_id          = local.vm_ids.pbs
  vm_name        = "pbs"
  vm_description = "Proxmox Backup Server — VM backups to TrueNAS NFS"
  tags           = ["pbs", "backup", "production"]

  cpu_cores         = 4
  memory_mb         = 4096
  boot_disk_size_gb = 32

  network_bridge      = local.proxmox.bridges.lan
  enable_dual_network = true
  secondary_bridge    = local.proxmox.bridges.storage

  pool_id = local.environments.prod.pools.compute

  iso_id = "local:iso/${local.pbs.filename}"
}
