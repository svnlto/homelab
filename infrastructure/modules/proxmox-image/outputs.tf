output "image_id" {
  description = "Proxmox file ID for the uploaded image"
  value       = proxmox_virtual_environment_file.image.id
}

output "image_name" {
  description = "Base name of the uploaded image"
  value       = var.image_name
}

output "proxmox_filename" {
  description = "Filename in Proxmox storage"
  value       = var.proxmox_filename
}
