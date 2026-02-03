# ==============================================================================
# TrueNAS Primary Server
# ==============================================================================

module "truenas_primary" {
  source = "../../../modules/truenas-vm"

  # Pass all inputs from terragrunt.hcl
  node_name         = var.node_name
  vm_id             = var.vm_id
  vm_name           = var.vm_name
  vm_description    = var.vm_description
  tags              = var.tags
  truenas_version   = var.truenas_version
  iso_id            = var.iso_id
  cpu_cores         = var.cpu_cores
  memory_mb         = var.memory_mb
  boot_disk_size_gb = var.boot_disk_size_gb
  mac_address       = var.mac_address
  pool_id           = var.pool_id
  enable_hostpci    = var.enable_hostpci
  hostpci_mapping   = var.hostpci_mapping
}
