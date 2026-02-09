# ==============================================================================
# Image Management - Production
# ==============================================================================
# Centralized management of images (ISO, disk images) used by VMs

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "provider" {
  path = find_in_parent_folders("provider.hcl")
}

locals {
  global_vars = read_terragrunt_config(find_in_parent_folders("globals.hcl"))
  truenas     = local.global_vars.locals.truenas
  nixos       = local.global_vars.locals.nixos
}

inputs = {
  # TrueNAS ISO
  truenas_url      = local.truenas.url
  truenas_filename = local.truenas.filename

  # NixOS ISO
  nixos_url      = local.nixos.iso_url
  nixos_filename = local.nixos.filename

  # Proxmox Storage
  proxmox_node = "din"
  datastore_id = "local"
}
