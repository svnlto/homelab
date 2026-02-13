# ==============================================================================
# Arr Media Stack - Input Variables
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

# VM Configuration
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
  type    = string
  default = ""
}

variable "tags" {
  type    = list(string)
  default = []
}

variable "cpu_cores" {
  type    = number
  default = 4
}

variable "memory_mb" {
  type    = number
  default = 8192
}

variable "boot_disk_size_gb" {
  type    = number
  default = 32
}

variable "network_bridge" {
  type    = string
  default = "vmbr20"
}

variable "enable_dual_network" {
  type    = bool
  default = false
}

variable "secondary_bridge" {
  type    = string
  default = "vmbr10"
}

variable "pool_id" {
  type    = string
  default = null
}

variable "iso_id" {
  type    = string
  default = null
}

# Cloud-init
variable "enable_cloud_init" {
  type    = bool
  default = false
}

variable "ip_address" {
  type    = string
  default = null
}

variable "gateway" {
  type    = string
  default = null
}

variable "nameserver" {
  type    = string
  default = null
}

variable "username" {
  type    = string
  default = null
}
