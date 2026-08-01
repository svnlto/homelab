# Linode Nanode in Singapore — Tailscale peer relay for dumper photo sync.
# Replaces shared DERP relay with a dedicated node for better throughput.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "provider" {
  path = "${get_terragrunt_dir()}/../provider.hcl"
}

inputs = {
  tailscale_auth_key = run_cmd("--terragrunt-quiet", "--terragrunt-global-cache", "op", "read", "op://Homelab/Tailscale Photo Relay Auth Key/credential")
  ssh_public_key     = run_cmd("--terragrunt-quiet", "--terragrunt-global-cache", "op", "read", "op://Homelab/proxmox/public key")
}
