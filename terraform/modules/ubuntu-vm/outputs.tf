output "vm_id" {
  description = "The ID of the created VM"
  value       = proxmox_virtual_environment_vm.this.vm_id
}

output "vm_name" {
  description = "The name of the created VM"
  value       = proxmox_virtual_environment_vm.this.name
}

output "ipv4_addresses" {
  description = "The IPv4 addresses of the VM"
  value       = proxmox_virtual_environment_vm.this.ipv4_addresses
}

output "ipv6_addresses" {
  description = "The IPv6 addresses of the VM"
  value       = proxmox_virtual_environment_vm.this.ipv6_addresses
}

output "mac_addresses" {
  description = "The MAC addresses of the VM"
  value       = proxmox_virtual_environment_vm.this.mac_addresses
}
