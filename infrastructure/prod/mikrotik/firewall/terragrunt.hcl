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
  ips         = local.global_vars.locals.infrastructure_ips
}

inputs = {
  vlan_interfaces = dependency.base.outputs.vlan_interfaces
  wan_interface   = local.mikrotik.wan.interface
  pihole_ip       = local.ips.pihole
}
