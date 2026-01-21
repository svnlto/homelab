# =============================================================================
# Packer Variables for Proxmox Node Image
# =============================================================================

# -----------------------------------------------------------------------------
# ISO Configuration
# -----------------------------------------------------------------------------
variable "iso_url" {
  type        = string
  description = "URL to the Debian ISO"
  default     = "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-13.2.0-amd64-netinst.iso"
}

variable "iso_checksum" {
  type        = string
  description = "Checksum for the ISO"
  default     = "sha256:677c4d57aa034dc192b5191870141057574c1b05df2b9569c0ee08aa4e32125d"
}

# -----------------------------------------------------------------------------
# VM Hardware Configuration
# -----------------------------------------------------------------------------
variable "disk_size" {
  type        = string
  description = "Size of the virtual disk"
  default     = "32G"
}

variable "memory" {
  type        = number
  description = "RAM in MB"
  default     = 4096
}

variable "cpus" {
  type        = number
  description = "Number of CPUs"
  default     = 4
}

# -----------------------------------------------------------------------------
# Network Configuration
# -----------------------------------------------------------------------------
variable "hostname" {
  type        = string
  description = "Hostname for the node"
  default     = "pve-node"
}

variable "domain" {
  type        = string
  description = "Domain name"
  default     = "local"
}

# -----------------------------------------------------------------------------
# Authentication
# -----------------------------------------------------------------------------
variable "ssh_username" {
  type        = string
  description = "SSH username for provisioning"
  default     = "root"
}

variable "ssh_password" {
  type        = string
  description = "SSH password for provisioning (change this!)"
  default     = "packer"
  sensitive   = true
}

variable "root_password_hash" {
  type        = string
  description = "Hashed root password for the final image (generate with: mkpasswd -m sha-512)"
  default     = ""  # Empty means password will be set by Ansible
  sensitive   = true
}

# -----------------------------------------------------------------------------
# Build Configuration
# -----------------------------------------------------------------------------
variable "output_format" {
  type        = string
  description = "Output format: raw (for bare-metal), qcow2 (for testing/VMs)"
  default     = "raw"

  validation {
    condition     = contains(["raw", "qcow2"], var.output_format)
    error_message = "Output format must be 'raw' or 'qcow2'."
  }
}

variable "headless" {
  type        = bool
  description = "Run build without GUI (set false to watch via VNC)"
  default     = true
}

variable "boot_wait" {
  type        = string
  description = "Time to wait before typing boot command"
  default     = "10s"
}

variable "ssh_timeout" {
  type        = string
  description = "SSH connection timeout"
  default     = "30m"
}

# -----------------------------------------------------------------------------
# Proxmox Configuration
# -----------------------------------------------------------------------------
variable "pve_version" {
  type        = string
  description = "Proxmox VE version to install (8 or 9)"
  default     = "8"

  validation {
    condition     = contains(["8", "9"], var.pve_version)
    error_message = "PVE version must be '8' or '9'."
  }
}

variable "pve_repository" {
  type        = string
  description = "Proxmox repository: enterprise, no-subscription, test"
  default     = "no-subscription"

  validation {
    condition     = contains(["enterprise", "no-subscription", "test"], var.pve_repository)
    error_message = "Repository must be 'enterprise', 'no-subscription', or 'test'."
  }
}

variable "remove_subscription_warning" {
  type        = bool
  description = "Remove the subscription nag popup"
  default     = true
}

# -----------------------------------------------------------------------------
# UEFI Configuration
# -----------------------------------------------------------------------------
variable "efi_boot" {
  type        = bool
  description = "Enable UEFI boot (recommended for modern hardware)"
  default     = false  # Disabled for direct kernel boot
}

variable "efi_firmware_code" {
  type        = string
  description = "Path to OVMF firmware code"
  default     = "/usr/share/OVMF/OVMF_CODE.fd"
}

variable "efi_firmware_vars" {
  type        = string
  description = "Path to OVMF firmware variables"
  default     = "/usr/share/OVMF/OVMF_VARS.fd"
}

# -----------------------------------------------------------------------------
# Optional Features
# -----------------------------------------------------------------------------
variable "install_cloud_init" {
  type        = bool
  description = "Install cloud-init for dynamic configuration"
  default     = false
}

variable "install_zfs" {
  type        = bool
  description = "Install ZFS support"
  default     = false
}

variable "configure_pcie_passthrough" {
  type        = bool
  description = "Configure IOMMU for PCIe passthrough"
  default     = false
}

# -----------------------------------------------------------------------------
# Ansible Configuration
# -----------------------------------------------------------------------------
variable "ansible_extra_vars" {
  type        = map(string)
  description = "Extra variables to pass to Ansible"
  default     = {}
}
