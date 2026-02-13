# ==============================================================================
# Dumper LXC Container - Input Variables
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

# Container Configuration
variable "node_name" {
  type = string
}

variable "container_id" {
  type = number
}

variable "container_name" {
  type = string
}

variable "container_description" {
  type    = string
  default = ""
}

variable "tags" {
  type    = list(string)
  default = []
}

variable "cores" {
  type    = number
  default = 1
}

variable "memory_mb" {
  type    = number
  default = 512
}

variable "disk_size_gb" {
  type    = number
  default = 2
}

variable "network_bridge" {
  type    = string
  default = "vmbr20"
}

variable "secondary_bridge" {
  type    = string
  default = null
}

variable "template_file_id" {
  type = string
}

variable "pool_id" {
  type    = string
  default = null
}

# Initialization
variable "ip_address" {
  type    = string
  default = null
}

variable "gateway" {
  type    = string
  default = null
}

variable "storage_ip" {
  type    = string
  default = null
}

variable "dns_servers" {
  type    = list(string)
  default = null
}
