# ==============================================================================
# Dumper LXC Container - Outputs
# ==============================================================================

output "container_id" {
  description = "Container ID"
  value       = module.dumper.container_id
}

output "container_name" {
  description = "Container hostname"
  value       = module.dumper.container_name
}

output "node_name" {
  description = "Proxmox node hosting the container"
  value       = module.dumper.node_name
}
