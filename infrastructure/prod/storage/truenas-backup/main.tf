# ==============================================================================
# TrueNAS Backup Server
# ==============================================================================

module "truenas_backup" {
  source = "../../../modules/truenas-vm"

  # Pass all inputs from terragrunt.hcl
  node_name           = var.node_name
  vm_id               = var.vm_id
  vm_name             = var.vm_name
  vm_description      = var.vm_description
  tags                = var.tags
  truenas_version     = var.truenas_version
  iso_id              = var.iso_id
  cpu_cores           = var.cpu_cores
  memory_mb           = var.memory_mb
  boot_disk_size_gb   = var.boot_disk_size_gb
  mac_address         = var.mac_address
  pool_id             = var.pool_id
  enable_dual_network = var.enable_dual_network
  storage_bridge      = var.storage_bridge
  enable_network_init = var.enable_network_init
  management_ip       = var.management_ip
  management_gateway  = var.management_gateway
  storage_ip          = var.storage_ip
  dns_server          = var.dns_server
}
