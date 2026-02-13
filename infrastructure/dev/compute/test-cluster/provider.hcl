# ==============================================================================
# K8s Cluster Provider Configuration
# ==============================================================================
# Custom provider config for Talos clusters (requires multiple providers)

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
    talos = {
      source  = "siderolabs/talos"
      version = "0.10.1"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.6.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.0.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.1.1"
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
  }
}

provider "talos" {}
EOF
}

inputs = {
  proxmox_api_url          = local.proxmox.api_url
  proxmox_api_token_id     = get_env("TF_VAR_proxmox_api_token_id", "")
  proxmox_api_token_secret = get_env("TF_VAR_proxmox_api_token_secret", "")
}
