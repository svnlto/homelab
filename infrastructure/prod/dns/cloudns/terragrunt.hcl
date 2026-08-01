# ClouDNS wildcard DNS records for K8s clusters.
# Each cluster gets a *.{cluster}.h.svenlito.com record pointing to its Tailscale IP.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

dependency "k8s_shared" {
  config_path = "../../compute/k8s-shared"

  mock_outputs = {
    traefik_tailscale_ip = "100.100.100.100"
  }
  mock_outputs_merge_strategy_with_state  = "shallow"
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

locals {
  global_vars = read_terragrunt_config(find_in_parent_folders("globals.hcl"))
  dns         = local.global_vars.locals.dns
}

inputs = {
  cloudns_auth_id       = run_cmd("--terragrunt-quiet", "--terragrunt-global-cache", "op", "read", "op://Homelab/ClouDNS API/auth_id")
  cloudns_auth_password = run_cmd("--terragrunt-quiet", "--terragrunt-global-cache", "op", "read", "op://Homelab/ClouDNS API/password")

  zone_name = local.dns.domain

  cluster_records = {
    shared = {
      subdomain    = "*.shared.h"
      tailscale_ip = dependency.k8s_shared.outputs.traefik_tailscale_ip
    }
  }
}
