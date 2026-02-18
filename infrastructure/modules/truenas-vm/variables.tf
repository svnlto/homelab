# TrueNAS VM module variables.

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

variable "truenas_version" {
  description = "TrueNAS version (for description)"
  type        = string
}

variable "iso_id" {
  description = "Pre-downloaded ISO file ID (e.g., 'local:iso/TrueNAS-SCALE-25.10.1.iso')"
  type        = string
}

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

variable "boot_disk_storage" {
  description = "Storage backend for boot disk"
  type        = string
  default     = "local-zfs"
}

variable "network_bridge" {
  description = "Network bridge for VM interfaces"
  type        = string
  default     = "vmbr20"
}

variable "mac_address" {
  description = "MAC address for primary network interface"
  type        = string
}

variable "vlan_id" {
  description = "VLAN ID for primary network interface (optional)"
  type        = number
  default     = null
}

variable "enable_dual_network" {
  description = "Enable second network interface for storage VLAN"
  type        = bool
  default     = false
}

variable "storage_bridge" {
  description = "Network bridge for storage interface (e.g., 'vmbr10')"
  type        = string
  default     = "vmbr10"
}

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

variable "hostpci_mappings" {
  description = "List of Proxmox PCI resource mapping names for HBA passthrough"
  type        = list(string)
  default     = []
}
