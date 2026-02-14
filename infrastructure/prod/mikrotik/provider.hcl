locals {
  global_vars = read_terragrunt_config(find_in_parent_folders("globals.hcl"))
  mikrotik    = local.global_vars.locals.mikrotik
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    routeros = {
      source  = "terraform-routeros/routeros"
      version = "~> 1.0"
    }
  }
}

provider "routeros" {
  hosturl  = var.mikrotik_api_url
  username = var.mikrotik_username
  password = var.mikrotik_password
  insecure = true
}
EOF
}

generate "provider_variables" {
  path      = "provider_variables.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
variable "mikrotik_api_url" {
  type = string
}

variable "mikrotik_username" {
  type      = string
  sensitive = true
}

variable "mikrotik_password" {
  type      = string
  sensitive = true
}
EOF
}

inputs = {
  mikrotik_api_url  = local.mikrotik.api_url
  mikrotik_username = get_env("MIKROTIK_USERNAME", "")
  mikrotik_password = get_env("MIKROTIK_PASSWORD", "")
}
