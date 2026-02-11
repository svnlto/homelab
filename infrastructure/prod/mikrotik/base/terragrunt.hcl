include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "provider" {
  path = find_in_parent_folders("provider.hcl")
}

locals {
  global_vars = read_terragrunt_config(find_in_parent_folders("globals.hcl"))
  mikrotik    = local.global_vars.locals.mikrotik
  vlans       = local.global_vars.locals.vlans
}

inputs = {
  mikrotik_api_url  = local.mikrotik.api_url
  mikrotik_username = get_env("MIKROTIK_USERNAME", "")
  mikrotik_password = get_env("MIKROTIK_PASSWORD", "")

  bridge_name  = local.mikrotik.bridge_name
  vlans        = local.vlans
  access_ports = local.mikrotik.access_ports
  trunk_ports  = local.mikrotik.trunk_ports

  wan_interface = local.mikrotik.wan.interface
  wan_address   = local.mikrotik.wan.address
  wan_gateway   = local.mikrotik.wan.gateway

  allowed_management_subnets = local.mikrotik.allowed_management_subnets
}
