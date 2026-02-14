# ISO and disk image management for production VMs.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "provider" {
  path = find_in_parent_folders("provider.hcl")
}

locals {
  global_vars = read_terragrunt_config(find_in_parent_folders("globals.hcl"))
  proxmox     = local.global_vars.locals.proxmox
  truenas     = local.global_vars.locals.truenas
  nixos       = local.global_vars.locals.nixos
}

inputs = {
  truenas_url      = local.truenas.url
  truenas_filename = local.truenas.filename
  truenas_checksum = local.truenas.checksum

  nixos_url      = local.nixos.iso_url
  nixos_filename = local.nixos.filename

  proxmox_node_primary   = local.proxmox.nodes.primary
  proxmox_node_secondary = local.proxmox.nodes.secondary
  datastore_id           = "local"
}
