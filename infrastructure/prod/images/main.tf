# ==============================================================================
# TrueNAS ISO Image
# ==============================================================================

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
