locals {
  global_vars = read_terragrunt_config(find_in_parent_folders("globals.hcl"))
  proxmox     = local.global_vars.locals.proxmox
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.94.0"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_api_url
  api_token = "$${var.proxmox_api_token_id}=$${var.proxmox_api_token_secret}"
  insecure  = true

  ssh {
    agent = true
  }
}
EOF
}

inputs = {
  proxmox_api_url          = local.proxmox.api_url
  proxmox_api_token_id     = get_env("TF_VAR_proxmox_api_token_id", "")
  proxmox_api_token_secret = get_env("TF_VAR_proxmox_api_token_secret", "")
}
