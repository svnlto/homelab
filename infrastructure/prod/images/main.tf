module "truenas_iso" {
  source = "../../modules/proxmox-image"

  download_url       = var.truenas_url
  image_name         = var.truenas_filename
  compression_format = "none"

  proxmox_node     = var.proxmox_node
  datastore_id     = var.datastore_id
  content_type     = "iso"
  proxmox_filename = var.truenas_filename
}

module "nixos_iso" {
  source = "../../modules/proxmox-image"

  download_url       = var.nixos_url
  image_name         = var.nixos_filename
  compression_format = "none"

  proxmox_node     = var.proxmox_node
  datastore_id     = var.datastore_id
  content_type     = "iso"
  proxmox_filename = var.nixos_filename
}

module "nixos_iso_grogu" {
  source = "../../modules/proxmox-image"

  download_url       = var.nixos_url
  image_name         = var.nixos_filename
  compression_format = "none"

  proxmox_node     = "grogu"
  datastore_id     = var.datastore_id
  content_type     = "iso"
  proxmox_filename = var.nixos_filename
}
