include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "provider" {
  path = find_in_parent_folders("provider.hcl")
}

locals {
  global_vars = read_terragrunt_config(find_in_parent_folders("globals.hcl"))
  mikrotik    = local.global_vars.locals.mikrotik
  ips         = local.global_vars.locals.infrastructure_ips
}

inputs = {
  mikrotik_api_url  = local.mikrotik.api_url
  mikrotik_username = get_env("MIKROTIK_USERNAME", "")
  mikrotik_password = get_env("MIKROTIK_PASSWORD", "")

  pihole_ip = local.ips.pihole
}
