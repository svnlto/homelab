# ==============================================================================
# Images - Outputs
# ==============================================================================

output "truenas_iso_id" {
  description = "Proxmox file ID for the TrueNAS ISO"
  value       = module.truenas_iso.image_id
}
