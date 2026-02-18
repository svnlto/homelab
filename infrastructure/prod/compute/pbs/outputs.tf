# ==============================================================================
# PBS VM - Outputs
# ==============================================================================

output "vm_id" {
  value = module.pbs.vm_id
}

output "vm_name" {
  value = module.pbs.vm_name
}

output "node_name" {
  value = module.pbs.node_name
}

output "mac_address" {
  value = module.pbs.mac_address
}
