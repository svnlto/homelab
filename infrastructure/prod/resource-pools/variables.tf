# ==============================================================================
# Resource Pools - Input Variables
# ==============================================================================

# Provider credentials (from provider.hcl)
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

# Resource Pool Configuration
variable "environment" {
  type        = string
  description = "Environment name (prod, dev)"
}

variable "pools" {
  type = map(object({
    id      = string
    comment = string
  }))
  description = "Map of resource pools to create"
}
