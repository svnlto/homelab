# ==============================================================================
# Images - Input Variables
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

# TrueNAS ISO
variable "truenas_url" {
  type        = string
  description = "TrueNAS ISO download URL"
}

variable "truenas_filename" {
  type        = string
  description = "TrueNAS ISO filename"
}

variable "proxmox_node" {
  type        = string
  description = "Proxmox node name"
}

variable "datastore_id" {
  type        = string
  description = "Datastore for ISO storage"
}
