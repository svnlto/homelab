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
