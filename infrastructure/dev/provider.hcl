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
      version = "0.97.1"
    }
    onepassword = {
      source  = "1Password/onepassword"
      version = "2.2.1"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_api_url
  api_token = "$${var.proxmox_api_token_id}=$${var.proxmox_api_token_secret}"
  insecure  = true

  ssh {
    agent    = true
    username = "root"
    node {
      name    = "${local.proxmox.nodes.primary}"
      address = "${local.global_vars.locals.infrastructure_ips.din_mgmt}"
    }
  }
}

provider "onepassword" {
  account = var.onepassword_account
}
EOF
}

generate "provider_variables" {
  path      = "provider_variables.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
variable "proxmox_api_url" {
  type        = string
  description = "Proxmox API URL"
}

variable "proxmox_api_token_id" {
  type        = string
  description = "Proxmox API token ID"
  sensitive   = true
}

variable "proxmox_api_token_secret" {
  type        = string
  description = "Proxmox API token secret"
  sensitive   = true
}

variable "onepassword_account" {
  type        = string
  description = "1Password account ID for desktop app integration"
}
EOF
}

inputs = {
  proxmox_api_url          = local.proxmox.api_url
  proxmox_api_token_id     = get_env("TF_VAR_proxmox_api_token_id", "")
  proxmox_api_token_secret = get_env("TF_VAR_proxmox_api_token_secret", "")
  onepassword_account      = get_env("OP_ACCOUNT", "")
}
