locals {
  global_vars = read_terragrunt_config(find_in_parent_folders("globals.hcl"))
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    tailscale = {
      source  = "tailscale/tailscale"
      version = "0.27.0"
    }
  }
}

provider "tailscale" {
  api_key = var.tailscale_api_key
  tailnet = var.tailscale_tailnet
}
EOF
}

generate "provider_variables" {
  path      = "provider_variables.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
variable "tailscale_api_key" {
  type      = string
  sensitive = true
}

variable "tailscale_tailnet" {
  type = string
}
EOF
}

inputs = {
  tailscale_api_key = get_env("TF_VAR_tailscale_api_key", "")
  tailscale_tailnet = get_env("TF_VAR_tailscale_tailnet", "")
}
