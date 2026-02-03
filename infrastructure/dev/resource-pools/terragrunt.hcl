# ==============================================================================
# Development Resource Pools
# ==============================================================================
# Creates Proxmox resource pools for organizing development VMs
#
# Pools:
#   - dev-storage: Development storage testing VMs
#   - dev-compute: Development and testing VMs

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "provider" {
  path = find_in_parent_folders("provider.hcl")
}

locals {
  global_vars  = read_terragrunt_config(find_in_parent_folders("globals.hcl"))
  environments = local.global_vars.locals.environments
}

inputs = {
  environment = "dev"
  pools = {
    storage = {
      id      = local.environments.dev.pools.storage
      comment = "Development Storage VMs (testing, experiments)"
    }
    compute = {
      id      = local.environments.dev.pools.compute
      comment = "Development Compute VMs (testing, experiments)"
    }
  }
}
