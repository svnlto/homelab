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

variable "onepassword_account" {
  type        = string
  description = "1Password account ID for desktop app integration"
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

# NixOS ISO
variable "nixos_url" {
  type        = string
  description = "NixOS ISO download URL"
}

variable "nixos_filename" {
  type        = string
  description = "NixOS ISO filename"
}

variable "proxmox_node" {
  type        = string
  description = "Proxmox node name"
}

variable "datastore_id" {
  type        = string
  description = "Datastore for ISO storage"
}
