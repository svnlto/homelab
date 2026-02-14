# Production Proxmox resource pools (prod-storage, prod-compute).

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
