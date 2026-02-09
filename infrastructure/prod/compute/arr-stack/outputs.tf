# ==============================================================================
# Arr Media Stack - Outputs
# ==============================================================================

output "vm_id" {
  value = module.arr_stack.vm_id
}

output "vm_name" {
  value = module.arr_stack.vm_name
}

output "node_name" {
  value = module.arr_stack.node_name
}

output "mac_address" {
  value = module.arr_stack.mac_address
}
