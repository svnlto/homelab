# ==============================================================================
# Generic VM Module - Input Variables
# ==============================================================================

# Proxmox Configuration
variable "node_name" {
  description = "Proxmox node name (e.g., 'din', 'grogu')"
  type        = string
}

variable "vm_id" {
  description = "Unique VM ID (e.g., 200, 300)"
  type        = number
}

variable "vm_name" {
  description = "VM display name"
  type        = string
}

variable "vm_description" {
  description = "VM description"
  type        = string
  default     = ""
}

variable "tags" {
  description = "VM tags"
  type        = list(string)
  default     = []
}

variable "pool_id" {
  description = "Proxmox resource pool ID (e.g., 'prod-compute')"
  type        = string
  default     = null
}

variable "start_on_boot" {
  description = "Start VM when Proxmox host boots"
  type        = bool
  default     = true
}

variable "startup_order" {
  description = "VM startup order (lower = starts first). Set to null to disable."
  type        = number
  default     = 2
}

variable "startup_up_delay" {
  description = "Seconds to wait after starting this VM before starting the next"
  type        = number
  default     = 30
}

variable "startup_down_delay" {
  description = "Seconds to wait after shutting down this VM before stopping the next"
  type        = number
  default     = 30
}

# Boot Configuration
variable "boot_mode" {
  description = "Boot mode: 'uefi' (OVMF + q35) or 'bios' (SeaBIOS + i440fx)"
  type        = string
  default     = "uefi"

  validation {
    condition     = contains(["uefi", "bios"], var.boot_mode)
    error_message = "boot_mode must be 'uefi' or 'bios'."
  }
}

# Boot Media (mutually exclusive)
variable "iso_id" {
  description = "ISO file ID for manual install (e.g., 'local:iso/nixos.iso'). Mutually exclusive with disk_image_id."
  type        = string
  default     = null
}

variable "disk_image_id" {
  description = "Disk image file ID for cloud images (e.g., 'local:iso/nixos.qcow2'). Mutually exclusive with iso_id."
  type        = string
  default     = null
}

# Hardware Configuration
variable "cpu_cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 4
}

variable "cpu_sockets" {
  description = "Number of CPU sockets"
  type        = number
  default     = 1
}

variable "cpu_type" {
  description = "CPU type (e.g., 'host', 'x86-64-v2-AES')"
  type        = string
  default     = "host"
}

variable "memory_mb" {
  description = "Memory in MB"
  type        = number
  default     = 8192
}

# Boot Disk
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

# Additional Disks
variable "additional_disks" {
  description = "List of additional disk sizes in GB"
  type        = list(number)
  default     = []
}

# Network Configuration
variable "network_bridge" {
  description = "Network bridge for primary interface"
  type        = string
  default     = "vmbr20"
}

variable "vlan_id" {
  description = "VLAN ID for primary network interface"
  type        = number
  default     = null
}

variable "mac_address" {
  description = "MAC address for primary network interface"
  type        = string
  default     = null
}

# Dual Network Configuration
variable "enable_dual_network" {
  description = "Enable second network interface"
  type        = bool
  default     = false
}

variable "secondary_bridge" {
  description = "Network bridge for secondary interface"
  type        = string
  default     = "vmbr20"
}

variable "secondary_vlan_id" {
  description = "VLAN ID for secondary network interface"
  type        = number
  default     = null
}

# Cloud-Init Configuration
variable "enable_cloud_init" {
  description = "Enable cloud-init initialization"
  type        = bool
  default     = false
}

variable "ip_address" {
  description = "Static IP address in CIDR format (e.g., '192.168.0.50/24')"
  type        = string
  default     = null
}

variable "gateway" {
  description = "Default gateway IP"
  type        = string
  default     = null
}

variable "nameserver" {
  description = "DNS server IP"
  type        = string
  default     = null
}

variable "username" {
  description = "Cloud-init default username"
  type        = string
  default     = null
}

variable "ssh_keys" {
  description = "SSH public keys for cloud-init"
  type        = list(string)
  default     = []
}

# PCI Passthrough Configuration
variable "enable_pci_passthrough" {
  description = "Enable PCI device passthrough"
  type        = bool
  default     = false
}

variable "pci_mapping_id" {
  description = "Proxmox PCI resource mapping name"
  type        = string
  default     = null
}

# QEMU Agent
variable "enable_qemu_agent" {
  description = "Enable QEMU guest agent"
  type        = bool
  default     = true
}
