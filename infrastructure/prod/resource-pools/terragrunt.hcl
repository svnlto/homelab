# ==============================================================================
# Production Resource Pools
# ==============================================================================
# Creates Proxmox resource pools for organizing production VMs
#
# Pools:
#   - prod-storage: TrueNAS Primary, TrueNAS Backup, storage-related VMs
#   - prod-compute: General compute VMs, applications

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
  environment = "prod"
  pools = {
    storage = {
      id      = local.environments.prod.pools.storage
      comment = "Production Storage VMs (TrueNAS, NFS, iSCSI)"
    }
    compute = {
      id      = local.environments.prod.pools.compute
      comment = "Production Compute VMs (applications, services)"
    }
  }
}
