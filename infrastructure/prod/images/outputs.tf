# ==============================================================================
# Images - Outputs
# ==============================================================================

output "truenas_iso_id" {
  description = "Proxmox file ID for the TrueNAS ISO"
  value       = module.truenas_iso.image_id
}

output "nixos_iso_id" {
  description = "Proxmox file ID for the NixOS ISO"
  value       = module.nixos_iso.image_id
}

output "talos_image_id_din" {
  description = "Proxmox file ID for the Talos image on din"
  value       = module.talos_image_din.image_id
}

output "talos_image_id_grogu" {
  description = "Proxmox file ID for the Talos image on grogu"
  value       = module.talos_image_grogu.image_id
}
