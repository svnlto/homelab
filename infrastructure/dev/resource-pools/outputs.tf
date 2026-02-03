# ==============================================================================
# Resource Pools - Outputs
# ==============================================================================

output "pool_ids" {
  description = "Created resource pool IDs"
  value       = { for k, v in proxmox_virtual_environment_pool.pools : k => v.pool_id }
}

output "pools" {
  description = "All resource pool details"
  value       = proxmox_virtual_environment_pool.pools
}
