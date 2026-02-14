resource "proxmox_virtual_environment_pool" "pools" {
  for_each = var.pools

  pool_id = each.value.id
  comment = each.value.comment
}
