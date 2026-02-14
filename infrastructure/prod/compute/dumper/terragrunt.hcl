# Dumper VM (VMID 202) on grogu — Tailscale rsync automation to TrueNAS.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "provider" {
  path = find_in_parent_folders("provider.hcl")
}

dependencies {
  paths = ["../../resource-pools"]
}

locals {
  global_vars  = read_terragrunt_config(find_in_parent_folders("globals.hcl"))
  ips          = local.global_vars.locals.infrastructure_ips
  environments = local.global_vars.locals.environments
}

inputs = {
  node_name      = "grogu"
  vm_id          = 202
  vm_name        = "dumper"
  vm_description = "NixOS - Tailscale rsync automation (photo dump to TrueNAS)"
  tags           = ["nixos", "tailscale", "rsync", "production"]

  cpu_cores         = 2
  memory_mb         = 2048
  boot_disk_size_gb = 8

  network_bridge      = "vmbr20"
  enable_dual_network = true
  secondary_bridge    = "vmbr10"

  pool_id = local.environments.prod.pools.compute

  iso_id = "local:iso/nixos-minimal-x86_64-linux.iso"
}
