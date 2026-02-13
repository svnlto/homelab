# ==============================================================================
# Jellyfin Media Server - Outputs
# ==============================================================================

output "vm_id" {
  value = module.jellyfin.vm_id
}

output "vm_name" {
  value = module.jellyfin.vm_name
}

output "node_name" {
  value = module.jellyfin.node_name
}

output "mac_address" {
  value = module.jellyfin.mac_address
}
