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
      version = "0.95.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "0.10.1"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.6.2"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.1.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.0.1"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = "2.1.3"
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

provider "helm" {
  kubernetes = {
    config_path = "$${path.module}/configs/kubeconfig-shared"
  }
}

provider "kubernetes" {
  config_path = "$${path.module}/configs/kubeconfig-shared"
}

provider "kubectl" {
  config_path = "$${path.module}/configs/kubeconfig-shared"
}
EOF
}

generate "provider_variables" {
  path      = "provider_variables.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
variable "proxmox_api_url" {
  type = string
}

variable "proxmox_api_token_id" {
  type = string
}

variable "proxmox_api_token_secret" {
  type      = string
  sensitive = true
}
EOF
}

inputs = {
  proxmox_api_url          = local.proxmox.api_url
  proxmox_api_token_id     = get_env("TF_VAR_proxmox_api_token_id", "")
  proxmox_api_token_secret = get_env("TF_VAR_proxmox_api_token_secret", "")
}
