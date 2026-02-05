module "talos_image" {
  source = "../../modules/proxmox-image"

  download_url       = "https://factory.talos.dev/image/${var.schematic_id}/${var.talos_version}/nocloud-amd64.raw.xz"
  image_name         = "talos-${var.schematic_id}-${var.talos_version}-nocloud-amd64.raw"
  compression_format = "xz"

  proxmox_node     = var.proxmox_node
  datastore_id     = var.datastore_id
  content_type     = "iso"
  proxmox_filename = "talos-${var.schematic_id}-${var.talos_version}-nocloud.img"
}
