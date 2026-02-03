# ==============================================================================
# ISO Images - Input Variables
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

# ISO Images
variable "iso_images" {
  type = map(object({
    node_name    = string
    datastore_id = string
    url          = string
    filename     = string
  }))
  description = "Map of ISO images to download"
}
