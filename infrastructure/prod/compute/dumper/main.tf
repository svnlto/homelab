data "onepassword_item" "ssh_key" {
  vault = "Personal"
  title = "proxmox"
}

module "dumper" {
  source = "../../../modules/vm"

  node_name           = var.node_name
  vm_id               = var.vm_id
  vm_name             = var.vm_name
  vm_description      = var.vm_description
  tags                = var.tags
  cpu_cores           = var.cpu_cores
  memory_mb           = var.memory_mb
  boot_disk_size_gb   = var.boot_disk_size_gb
  network_bridge      = var.network_bridge
  enable_dual_network = var.enable_dual_network
  secondary_bridge    = var.secondary_bridge
  pool_id             = var.pool_id
  iso_id              = var.iso_id

  enable_cloud_init = var.enable_cloud_init
  ip_address        = var.ip_address
  gateway           = var.gateway
  nameserver        = var.nameserver
  username          = var.username
  ssh_keys          = [data.onepassword_item.ssh_key.public_key]
}
