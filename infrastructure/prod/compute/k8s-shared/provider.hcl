# ==============================================================================
# K8s Cluster Provider Configuration
# ==============================================================================
# Custom provider config for Talos clusters (requires multiple providers)

locals {
  global_vars     = read_terragrunt_config(find_in_parent_folders("globals.hcl"))
  proxmox         = local.global_vars.locals.proxmox
  kubeconfig_path = "${get_terragrunt_dir()}/configs/kubeconfig-shared"
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
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
    config_path = "${local.kubeconfig_path}"
  }
}

provider "kubernetes" {
  config_path = "${local.kubeconfig_path}"
}

provider "kubectl" {
  config_path = "${local.kubeconfig_path}"
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
