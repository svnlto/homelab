# ==============================================================================
# ISO Image Management
# ==============================================================================
# Centralized downloads of ISO images

resource "proxmox_virtual_environment_download_file" "iso_images" {
  for_each = var.iso_images

  content_type        = "iso"
  datastore_id        = each.value.datastore_id
  node_name           = each.value.node_name
  url                 = each.value.url
  file_name           = each.value.filename
  overwrite           = false
  overwrite_unmanaged = true # Allow Terraform to adopt existing ISO files
}
