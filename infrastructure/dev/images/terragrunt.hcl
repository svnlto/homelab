# ==============================================================================
# Image Management - Development
# ==============================================================================
# Persistent storage for VM images (Talos, ISOs, disk images)

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "provider" {
  path = find_in_parent_folders("provider.hcl")
}

locals {
  global_vars = read_terragrunt_config(find_in_parent_folders("globals.hcl"))
}

inputs = {
  # Talos Version
  talos_version = "v1.12.2"

  # Image Factory Schematic ID (with qemu-guest-agent and iscsi-tools extensions)
  schematic_id = "dc7b152cb3ea99b821fcb7340ce7168313ce393d663740b791c36f6e95fc8586"

  # Proxmox Storage
  proxmox_node = "din"
  datastore_id = "local"
}
