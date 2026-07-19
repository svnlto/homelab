# TrueNAS Primary (VMID 300) on grogu — internal HBA (bulk) passthrough + SCSI SSD passthrough (ssd pool).

terraform {
  source = "${get_repo_root()}/infrastructure/modules//truenas-vm"
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "provider" {
  path = find_in_parent_folders("provider.hcl")
}

dependencies {
  paths = ["../../images"]
}

locals {
  global_vars = read_terragrunt_config(find_in_parent_folders("globals.hcl"))
  truenas     = local.global_vars.locals.truenas
  ips         = local.global_vars.locals.infrastructure_ips
  vlans       = local.global_vars.locals.vlans
  proxmox     = local.global_vars.locals.proxmox
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

  enable_network_init = true
  management_ip       = "${local.ips.truenas_primary_mgmt}/24"
  management_gateway  = local.vlans.lan.gateway
  storage_ip          = "${local.ips.truenas_primary_storage}/24"
  dns_server          = local.ips.pihole

  hostpci_mappings = [
    local.proxmox.resource_mappings.truenas_bulk_hba_a,
    local.proxmox.resource_mappings.truenas_bulk_hba_b,
  ]

  # 'ssd' pool SSDs on grogu's onboard SATA (not on a passthrough HBA) — handed
  # to TrueNAS as raw scsi disks so it can import the ssd mirror. Serials set to
  # avoid TrueNAS's duplicate-empty-serial pool-create block.
  passthrough_disks = [
    { path_in_datastore = "/dev/disk/by-id/ata-SAMSUNG_MZNTY256HDHP-000L7_S305NYAH672931", serial = "S305NYAH672931" },
    { path_in_datastore = "/dev/disk/by-id/ata-Micron_1100_MTFDDAV256TBN_18341E3E72A3", serial = "18341E3E72A3" },
  ]
}
