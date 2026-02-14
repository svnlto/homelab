# ==============================================================================
# LXC Container Module - Input Variables
# ==============================================================================

# Proxmox Configuration
variable "node_name" {
  description = "Proxmox node name (e.g., 'din', 'grogu')"
  type        = string
}

variable "container_id" {
  description = "Unique container ID (e.g., 202)"
  type        = number
}

variable "container_name" {
  description = "Container hostname"
  type        = string
}

variable "container_description" {
  description = "Container description"
  type        = string
  default     = "NixOS LXC Container"
}

variable "tags" {
  description = "Container tags"
  type        = list(string)
  default     = ["nixos"]
}

variable "pool_id" {
  description = "Proxmox resource pool ID"
  type        = string
  default     = null
}

variable "unprivileged" {
  description = "Run as unprivileged container (disable for NFS mounts, Tailscale)"
  type        = bool
  default     = true
}

# Hardware Configuration
variable "cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 1
}

variable "memory_mb" {
  description = "Memory in MB"
  type        = number
  default     = 512
}

variable "disk_size_gb" {
  description = "Root filesystem size in GB"
  type        = number
  default     = 2
}

# Template
variable "template_file_id" {
  description = "LXC template file ID (e.g., 'local:vztmpl/nixos-lxc.tar.xz')"
  type        = string
}

# Network Configuration
variable "network_bridge" {
  description = "Network bridge for primary interface"
  type        = string
  default     = "vmbr20"
}

variable "secondary_bridge" {
  description = "Network bridge for secondary interface (storage VLAN)"
  type        = string
  default     = null
}

# Initialization
variable "ip_address" {
  description = "Primary IP address (CIDR format, e.g., '192.168.0.52/24')"
  type        = string
  default     = null
}

variable "gateway" {
  description = "Default gateway IP"
  type        = string
  default     = null
}

variable "storage_ip" {
  description = "Storage network IP address (CIDR format, e.g., '10.10.10.52/24')"
  type        = string
  default     = null
}

variable "dns_servers" {
  description = "DNS server IPs"
  type        = list(string)
  default     = null
}
