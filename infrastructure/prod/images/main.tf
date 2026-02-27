module "truenas_iso" {
  source = "../../modules/proxmox-image"

  download_url       = var.truenas_url
  image_name         = var.truenas_filename
  checksum           = var.truenas_checksum
  compression_format = "none"

  proxmox_node     = var.proxmox_node_primary
  datastore_id     = var.datastore_id
  content_type     = "iso"
  proxmox_filename = var.truenas_filename
}

module "nixos_iso" {
  source = "../../modules/proxmox-image"

  download_url       = var.nixos_url
  image_name         = var.nixos_filename
  checksum           = var.nixos_checksum
  compression_format = "none"

  proxmox_node     = var.proxmox_node_primary
  datastore_id     = var.datastore_id
  content_type     = "iso"
  proxmox_filename = var.nixos_filename
}

module "truenas_iso_grogu" {
  source = "../../modules/proxmox-image"

  download_url       = var.truenas_url
  image_name         = var.truenas_filename
  checksum           = var.truenas_checksum
  compression_format = "none"

  proxmox_node     = var.proxmox_node_secondary
  datastore_id     = var.datastore_id
  content_type     = "iso"
  proxmox_filename = var.truenas_filename
}

module "nixos_iso_grogu" {
  source = "../../modules/proxmox-image"

  download_url       = var.nixos_url
  image_name         = var.nixos_filename
  checksum           = var.nixos_checksum
  compression_format = "none"

  proxmox_node     = var.proxmox_node_secondary
  datastore_id     = var.datastore_id
  content_type     = "iso"
  proxmox_filename = var.nixos_filename
}

module "talos_image_din" {
  source = "../../modules/proxmox-image"

  download_url       = "https://factory.talos.dev/image/${var.talos_schematic_id}/${var.talos_version}/nocloud-amd64.raw.xz"
  image_name         = "talos-${var.talos_schematic_id}-${var.talos_version}-nocloud-amd64.raw"
  compression_format = "xz"

  proxmox_node     = var.proxmox_node_primary
  datastore_id     = var.datastore_id
  content_type     = "iso"
  proxmox_filename = "talos-${var.talos_schematic_id}-${var.talos_version}-nocloud.img"
}

module "talos_image_grogu" {
  source = "../../modules/proxmox-image"

  download_url       = "https://factory.talos.dev/image/${var.talos_schematic_id}/${var.talos_version}/nocloud-amd64.raw.xz"
  image_name         = "talos-${var.talos_schematic_id}-${var.talos_version}-nocloud-amd64.raw"
  compression_format = "xz"

  proxmox_node     = var.proxmox_node_secondary
  datastore_id     = var.datastore_id
  content_type     = "iso"
  proxmox_filename = "talos-${var.talos_schematic_id}-${var.talos_version}-nocloud.img"
}

module "talos_image_gpu_grogu" {
  source = "../../modules/proxmox-image"

  download_url       = "https://factory.talos.dev/image/${var.talos_gpu_schematic_id}/${var.talos_version}/nocloud-amd64.raw.xz"
  image_name         = "talos-${var.talos_gpu_schematic_id}-${var.talos_version}-nocloud-amd64.raw"
  compression_format = "xz"

  proxmox_node     = var.proxmox_node_secondary
  datastore_id     = var.datastore_id
  content_type     = "iso"
  proxmox_filename = "talos-${var.talos_gpu_schematic_id}-${var.talos_version}-nocloud.img"
}
