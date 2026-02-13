# ==============================================================================
# LXC Container Module - Outputs
# ==============================================================================

output "container_id" {
  description = "Container ID"
  value       = proxmox_virtual_environment_container.container.vm_id
}

output "container_name" {
  description = "Container hostname"
  value       = var.container_name
}

output "node_name" {
  description = "Proxmox node hosting the container"
  value       = proxmox_virtual_environment_container.container.node_name
}
