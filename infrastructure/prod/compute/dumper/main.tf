# ==============================================================================
# Dumper LXC Container
# ==============================================================================

module "dumper" {
  source = "../../../modules/lxc"

  # Pass all inputs from terragrunt.hcl
  node_name             = var.node_name
  container_id          = var.container_id
  container_name        = var.container_name
  container_description = var.container_description
  tags                  = var.tags
  cores                 = var.cores
  memory_mb             = var.memory_mb
  disk_size_gb          = var.disk_size_gb
  network_bridge        = var.network_bridge
  secondary_bridge      = var.secondary_bridge
  template_file_id      = var.template_file_id
  pool_id               = var.pool_id

  # Initialization
  ip_address  = var.ip_address
  gateway     = var.gateway
  storage_ip  = var.storage_ip
  dns_servers = var.dns_servers
}
