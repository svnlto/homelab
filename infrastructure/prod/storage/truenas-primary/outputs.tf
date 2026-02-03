# ==============================================================================
# TrueNAS Primary - Outputs
# ==============================================================================

output "vm_id" {
  value = module.truenas_primary.vm_id
}

output "vm_name" {
  value = module.truenas_primary.vm_name
}

output "node_name" {
  value = module.truenas_primary.node_name
}

output "mac_address" {
  value = module.truenas_primary.mac_address
}
