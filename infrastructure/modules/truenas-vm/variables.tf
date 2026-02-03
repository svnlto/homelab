# ==============================================================================
# TrueNAS VM Module - Input Variables
# ==============================================================================

# Proxmox Configuration
variable "node_name" {
  description = "Proxmox node name (e.g., 'din', 'grogu')"
  type        = string
}

variable "vm_id" {
  description = "Unique VM ID (e.g., 300, 301)"
  type        = number
}

variable "vm_name" {
  description = "VM display name"
  type        = string
}

variable "vm_description" {
  description = "VM description"
  type        = string
  default     = "TrueNAS SCALE - Network Attached Storage"
}

variable "tags" {
  description = "VM tags"
  type        = list(string)
  default     = ["truenas", "storage", "nas"]
}

variable "pool_id" {
  description = "Proxmox resource pool ID (e.g., 'prod-storage', 'dev-compute')"
  type        = string
  default     = null
}

# TrueNAS ISO Configuration
variable "truenas_version" {
  description = "TrueNAS version (for description)"
  type        = string
}

variable "iso_id" {
  description = "Pre-downloaded ISO file ID (e.g., 'local:iso/TrueNAS-SCALE-25.10.1.iso')"
  type        = string
}

# Hardware Configuration
variable "cpu_cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 8
}

variable "memory_mb" {
  description = "Memory in MB"
  type        = number
  default     = 32768
}

variable "boot_disk_size_gb" {
  description = "Boot disk size in GB"
  type        = number
  default     = 32
}

# Network Configuration
variable "mac_address" {
  description = "MAC address for primary network interface"
  type        = string
}

variable "vlan_id" {
  description = "VLAN ID for primary network interface (optional)"
  type        = number
  default     = null
}

# Dual Network Configuration (optional - for backup server)
variable "enable_dual_network" {
  description = "Enable second network interface for storage VLAN"
  type        = bool
  default     = false
}

variable "storage_vlan_id" {
  description = "VLAN ID for storage network (when dual network enabled)"
  type        = number
  default     = null
}

# Network Initialization (optional - for backup server)
variable "enable_network_init" {
  description = "Enable network initialization via cloud-init"
  type        = bool
  default     = false
}

variable "management_ip" {
  description = "Management IP address (CIDR format, e.g., '192.168.0.14/24')"
  type        = string
  default     = null
}

variable "management_gateway" {
  description = "Management gateway IP"
  type        = string
  default     = null
}

variable "storage_ip" {
  description = "Storage network IP address (CIDR format, e.g., '10.10.10.14/24')"
  type        = string
  default     = null
}

variable "dns_server" {
  description = "DNS server IP"
  type        = string
  default     = null
}

# HBA Passthrough Configuration (optional - for primary server)
variable "enable_hostpci" {
  description = "Enable PCI device passthrough (HBA)"
  type        = bool
  default     = false
}

variable "hostpci_mapping" {
  description = "Host PCI device mapping name (Proxmox resource mapping)"
  type        = string
  default     = null
}
