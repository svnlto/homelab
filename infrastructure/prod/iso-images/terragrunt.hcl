# ==============================================================================
# ISO Image Management - Production
# ==============================================================================
# Centralized management of ISO images used by VMs
# This prevents conflicts when multiple VMs reference the same ISO

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "provider" {
  path = find_in_parent_folders("provider.hcl")
}

locals {
  global_vars = read_terragrunt_config(find_in_parent_folders("globals.hcl"))
  truenas     = local.global_vars.locals.truenas
}

inputs = {
  iso_images = {
    truenas = {
      node_name    = "din" # Download to din node
      datastore_id = "local"
      url          = local.truenas.url
      filename     = local.truenas.filename
    }
  }
}
