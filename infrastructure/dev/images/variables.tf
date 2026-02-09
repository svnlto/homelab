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

variable "talos_version" {
  description = "Talos Linux version"
  type        = string
}

variable "schematic_id" {
  description = "Talos Image Factory schematic ID"
  type        = string
}

variable "proxmox_node" {
  description = "Proxmox node name"
  type        = string
}

variable "datastore_id" {
  description = "Datastore for image storage"
  type        = string
}
