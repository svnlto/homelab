# ==============================================================================
# TrueNAS Backup - Outputs
# ==============================================================================

output "vm_id" {
  value = module.truenas_backup.vm_id
}

output "vm_name" {
  value = module.truenas_backup.vm_name
}

output "node_name" {
  value = module.truenas_backup.node_name
}

output "mac_address" {
  value = module.truenas_backup.mac_address
}
