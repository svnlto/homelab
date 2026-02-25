# Linode Nanode in Singapore — Tailscale peer relay for dumper photo sync.
# Replaces shared DERP relay with a dedicated node for better throughput.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "provider" {
  path = "${get_terragrunt_dir()}/../provider.hcl"
}

inputs = {
  tailscale_auth_key = get_env("TF_VAR_tailscale_auth_key", "")
  ssh_public_key     = get_env("TF_VAR_ssh_public_key", "")
}
