# Tailscale ACL policy — manages the full tailnet access control list.
# WARNING: tailscale_acl replaces the ENTIRE policy. All rules must be defined here.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "provider" {
  path = "${get_terragrunt_dir()}/../provider.hcl"
}

inputs = {
  acl_tags = {
    "k8s"        = ["autogroup:admin"]
    "dumper-src" = ["autogroup:admin"]
  }

  mullvad_exit_node_ip = "100.85.110.44"

  k8s_auto_approved_routes = ["10.0.0.0/8"]
}
