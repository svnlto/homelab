# ==============================================================================
# TrueNAS VM Module - Outputs
# ==============================================================================

output "vm_id" {
  description = "TrueNAS VM ID"
  value       = proxmox_virtual_environment_vm.truenas.vm_id
}

output "vm_name" {
  description = "TrueNAS VM name"
  value       = proxmox_virtual_environment_vm.truenas.name
}

output "node_name" {
  description = "Proxmox node hosting the VM"
  value       = proxmox_virtual_environment_vm.truenas.node_name
}

output "mac_address" {
  description = "Primary network interface MAC address"
  value       = var.mac_address
}
