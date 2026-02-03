# ==============================================================================
# ISO Images - Outputs
# ==============================================================================

output "iso_ids" {
  description = "Downloaded ISO file IDs"
  value       = { for k, v in proxmox_virtual_environment_download_file.iso_images : k => v.id }
}

output "iso_files" {
  description = "ISO file details"
  value       = proxmox_virtual_environment_download_file.iso_images
}
