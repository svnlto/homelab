# Talos image management for dev clusters.

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
  talos_version = "v1.12.2"
  schematic_id  = "dc7b152cb3ea99b821fcb7340ce7168313ce393d663740b791c36f6e95fc8586"
  proxmox_node  = "din"
  datastore_id  = "local"
}
