output "talos_image_id" {
  description = "Proxmox file ID for the Talos disk image"
  value       = module.talos_image.image_id
}

output "talos_version" {
  description = "Talos version of the uploaded image"
  value       = var.talos_version
}

output "schematic_id" {
  description = "Schematic ID of the uploaded image"
  value       = var.schematic_id
}
