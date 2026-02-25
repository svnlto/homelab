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
    linode = {
      source  = "linode/linode"
      version = "3.9.0"
    }
  }
}

provider "linode" {
  token = var.linode_api_token
}
EOF
}

generate "provider_variables" {
  path      = "provider_variables.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
variable "linode_api_token" {
  type        = string
  description = "Linode API token"
  sensitive   = true
}
EOF
}

inputs = {
  linode_api_token = get_env("TF_VAR_linode_api_token", "")
}
