include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "provider" {
  path = find_in_parent_folders("provider.hcl")
}

dependency "base" {
  config_path = "../../base"
}

locals {
  global_vars = read_terragrunt_config(find_in_parent_folders("globals.hcl"))
  vlan        = local.global_vars.locals.vlans.k8s_shared
  dhcp        = local.global_vars.locals.dhcp_pools.k8s_shared
}

inputs = {
  mikrotik_api_url  = local.global_vars.locals.mikrotik.api_url
  mikrotik_username = get_env("MIKROTIK_USERNAME", "")
  mikrotik_password = get_env("MIKROTIK_PASSWORD", "")

  vlan_name      = local.vlan.name
  vlan_id        = local.vlan.id
  vlan_interface = dependency.base.outputs.vlan_interfaces["k8s_shared"]
  subnet         = local.vlan.subnet
  gateway        = local.vlan.gateway
  dhcp_start     = local.dhcp.start
  dhcp_end       = local.dhcp.end
  dhcp_lease     = local.dhcp.lease
  dns_servers    = local.dhcp.dns
}
