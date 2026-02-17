include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "provider" {
  path = find_in_parent_folders("provider.hcl")
}

dependency "base" {
  config_path = "../base"
}

locals {
  global_vars = read_terragrunt_config(find_in_parent_folders("globals.hcl"))
  mikrotik    = local.global_vars.locals.mikrotik
}

inputs = {
  wan_interface  = local.mikrotik.wan.interface
  download_limit = local.mikrotik.qos.download_limit
  upload_limit   = local.mikrotik.qos.upload_limit
  bulk_hosts     = local.mikrotik.qos.bulk_hosts
}
