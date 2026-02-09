# ==============================================================================
# Generic VM Module - Outputs
# ==============================================================================

output "vm_id" {
  description = "VM ID"
  value       = proxmox_virtual_environment_vm.vm.vm_id
}

output "vm_name" {
  description = "VM name"
  value       = proxmox_virtual_environment_vm.vm.name
}

output "node_name" {
  description = "Proxmox node hosting the VM"
  value       = proxmox_virtual_environment_vm.vm.node_name
}

output "mac_address" {
  description = "Primary network interface MAC address"
  value       = var.mac_address
}

output "ipv4_addresses" {
  description = "IPv4 addresses reported by QEMU agent"
  value       = proxmox_virtual_environment_vm.vm.ipv4_addresses
}
