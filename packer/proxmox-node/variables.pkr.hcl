# =============================================================================
# Variables for Proxmox Node Image Builder
# =============================================================================

# -----------------------------------------------------------------------------
# Proxmox Configuration
# -----------------------------------------------------------------------------
variable "pve_version" {
  type        = string
  default     = "8"
  description = "Proxmox VE major version"
}

variable "pve_repository" {
  type        = string
  default     = "pve-no-subscription"
  description = "Proxmox repository: pve-enterprise, pve-no-subscription, or pvetest"
}

variable "remove_subscription_warning" {
  type        = bool
  default     = true
  description = "Remove Proxmox subscription nag dialog"
}

# -----------------------------------------------------------------------------
# VM Hardware Configuration
# -----------------------------------------------------------------------------
variable "memory" {
  type        = number
  default     = 4096
  description = "VM memory in MB"
}

variable "cpus" {
  type        = number
  default     = 4
  description = "Number of CPUs"
}

variable "disk_size" {
  type        = string
  default     = "32G"
  description = "Disk size"
}

# -----------------------------------------------------------------------------
# Output Configuration
# -----------------------------------------------------------------------------
variable "output_format" {
  type        = string
  default     = "qcow2"
  description = "Output format: qcow2 or raw"

  validation {
    condition     = contains(["qcow2", "raw"], var.output_format)
    error_message = "The output_format must be either qcow2 or raw."
  }
}

variable "headless" {
  type        = bool
  default     = true
  description = "Run build headless (no VNC window)"
}

# -----------------------------------------------------------------------------
# Network Configuration
# -----------------------------------------------------------------------------
variable "hostname" {
  type        = string
  default     = "pve"
  description = "Node hostname"
}

variable "domain" {
  type        = string
  default     = "local"
  description = "Node domain"
}

# -----------------------------------------------------------------------------
# Authentication
# -----------------------------------------------------------------------------
variable "ssh_password" {
  type        = string
  default     = "packer"
  sensitive   = true
  description = "Root password for build"
}

# -----------------------------------------------------------------------------
# Feature Flags
# -----------------------------------------------------------------------------
variable "install_cloud_init" {
  type        = bool
  default     = true
  description = "Install cloud-init for VM provisioning"
}

variable "install_zfs" {
  type        = bool
  default     = true
  description = "Install ZFS support"
}

variable "install_ceph" {
  type        = bool
  default     = false
  description = "Install Ceph cluster support (adds 40-60 min to build)"
}

variable "configure_pcie_passthrough" {
  type        = bool
  default     = true
  description = "Configure IOMMU/PCIe passthrough"
}

# -----------------------------------------------------------------------------
# Ansible Configuration
# -----------------------------------------------------------------------------
variable "ansible_playbook" {
  type        = string
  default     = "/ansible/playbooks/packer-proxmox-node.yml"
  description = "Path to Ansible playbook"
}

variable "ansible_config" {
  type        = string
  default     = "/ansible/ansible.cfg"
  description = "Path to Ansible config"
}

variable "ansible_extra_vars" {
  type        = map(string)
  default     = {}
  description = "Additional Ansible variables"
}

variable "proxmox_ssh_public_key" {
  type        = string
  default     = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGAfz+KUctvSo0azvIQhHY2eBvKhT3pHRE0vpNtvpjMY"
  description = "SSH public key for root access"
}
