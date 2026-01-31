variable "vm_name" {
  description = "Name of the VM"
  type        = string
}

variable "ssh_keys" {
  description = "List of SSH public keys for the VM user"
  type        = list(string)
}

variable "node_name" {
  description = "Proxmox node name"
  type        = string
  default     = "pve"
}

variable "description" {
  description = "VM description"
  type        = string
  default     = "Ubuntu 24.04 LTS VM"
}

variable "template_vm_id" {
  description = "VM ID of the Ubuntu template to clone from"
  type        = number
  default     = 9000
}

variable "cpu_cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 2
}

variable "cpu_type" {
  description = "CPU type"
  type        = string
  default     = "host"
}

variable "memory_mb" {
  description = "Memory in MB"
  type        = number
  default     = 4096
}

variable "disk_size_gb" {
  description = "Disk size in GB"
  type        = number
  default     = 32
}

variable "datastore_id" {
  description = "Proxmox datastore ID"
  type        = string
  default     = "local-lvm"
}

variable "network_bridge" {
  description = "Network bridge"
  type        = string
  default     = "vmbr0"
}

variable "network_firewall" {
  description = "Enable firewall on network interface"
  type        = bool
  default     = false
}

variable "start_on_boot" {
  description = "Start VM on Proxmox boot"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags for the VM (ubuntu and terraform are added automatically)"
  type        = list(string)
  default     = []
}

variable "vm_user" {
  description = "Username for the VM"
  type        = string
  default     = "ubuntu"
}

variable "ipv4_address" {
  description = "IPv4 address (use 'dhcp' for DHCP)"
  type        = string
  default     = "dhcp"
}

variable "ipv4_gateway" {
  description = "IPv4 gateway (only used if ipv4_address is not 'dhcp')"
  type        = string
  default     = null
}

variable "dns_servers" {
  description = "DNS servers"
  type        = list(string)
  default     = ["192.168.0.53"] # Pi-hole DNS
}

variable "gpu_passthrough_enabled" {
  description = "Enable GPU passthrough (WARNING: Only ONE VM can use a specific GPU at a time)"
  type        = bool
  default     = false
}

variable "gpu_mapping_id" {
  description = "GPU resource mapping ID (only used if gpu_passthrough_enabled is true)"
  type        = string
  default     = "intel-igpu"
  validation {
    condition     = var.gpu_passthrough_enabled == false || var.gpu_mapping_id != ""
    error_message = "gpu_mapping_id must be set when gpu_passthrough_enabled is true"
  }
}

variable "ansible_playbook" {
  description = "Path to Ansible playbook to run after VM creation (optional)"
  type        = string
  default     = null
}

variable "ansible_user" {
  description = "SSH user for Ansible connection (defaults to vm_user)"
  type        = string
  default     = null
}

variable "ansible_extra_vars" {
  description = "Extra variables to pass to Ansible as key-value pairs"
  type        = map(string)
  default     = {}
}

variable "vga_type" {
  description = "VGA adapter type (std, qxl, virtio, serial0, etc.)"
  type        = string
  default     = null
  validation {
    condition     = var.vga_type == null || contains(["std", "qxl", "qxl2", "qxl3", "qxl4", "virtio", "virtio-gl", "serial0", "serial1", "serial2", "serial3", "vmware", "cirrus", "none"], var.vga_type)
    error_message = "vga_type must be one of: std, qxl, qxl2, qxl3, qxl4, virtio, virtio-gl, serial0-3, vmware, cirrus, none"
  }
}

variable "vga_memory" {
  description = "VGA memory in MB (4-512, default is 16MB)"
  type        = number
  default     = null
  validation {
    condition     = var.vga_memory == null || (var.vga_memory >= 4 && var.vga_memory <= 512)
    error_message = "vga_memory must be between 4 and 512 MB"
  }
}
