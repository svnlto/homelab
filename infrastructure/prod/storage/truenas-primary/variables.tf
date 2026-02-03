# ==============================================================================
# TrueNAS Primary - Input Variables
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

# TrueNAS VM Configuration
variable "node_name" {
  type = string
}

variable "vm_id" {
  type = number
}

variable "vm_name" {
  type = string
}

variable "vm_description" {
  type = string
}

variable "tags" {
  type = list(string)
}

variable "truenas_version" {
  type = string
}

variable "iso_id" {
  type = string
}

variable "cpu_cores" {
  type = number
}

variable "memory_mb" {
  type = number
}

variable "boot_disk_size_gb" {
  type = number
}

variable "mac_address" {
  type = string
}

variable "pool_id" {
  type    = string
  default = null
}

variable "enable_hostpci" {
  type = bool
}

variable "hostpci_mapping" {
  type    = string
  default = null
}
