# Packer configuration for Ubuntu 24.04 LTS template on Proxmox
# This creates an immutable VM template that can be cloned quickly

packer {
  required_plugins {
    proxmox = {
      version = ">= 1.1.8"
      source  = "github.com/hashicorp/proxmox"
    }
    ansible = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/ansible"
    }
  }
}

# Variables
variable "proxmox_api_url" {
  type    = string
  default = "https://192.168.0.10:8006/api2/json"
}

variable "proxmox_api_token_id" {
  type      = string
  sensitive = true
  default   = env("PROXMOX_TOKEN_ID")
}

variable "proxmox_api_token_secret" {
  type      = string
  sensitive = true
  default   = env("PROXMOX_TOKEN_SECRET")
}

variable "proxmox_node" {
  type    = string
  default = "pve"
}

variable "proxmox_storage_pool" {
  type    = string
  default = "local-lvm"
}

variable "template_name" {
  type    = string
  default = "ubuntu-24.04-template"
}

variable "vm_id" {
  type    = number
  default = 9000
}

# Source configuration - Build from Ubuntu Server ISO
source "proxmox-iso" "ubuntu_template" {
  # Proxmox connection
  proxmox_url              = var.proxmox_api_url
  insecure_skip_tls_verify = true
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  node                     = var.proxmox_node

  # VM settings
  vm_id                = var.vm_id
  vm_name              = var.template_name
  template_description = "Ubuntu 24.04 LTS Base Template (Packer)"

  # Boot ISO
  boot_iso {
    type             = "scsi"
    iso_file         = "local:iso/ubuntu-24.04.3-live-server-amd64.iso"
    iso_storage_pool = "local"
    unmount          = true
  }

  # Cloud-Init drive (needed for template cloning)
  cloud_init              = true
  cloud_init_storage_pool = var.proxmox_storage_pool

  # VM Hardware
  cores    = 2
  sockets  = 1
  memory   = 2048
  cpu_type = "host"
  machine  = "q35"
  bios     = "ovmf"

  # EFI Disk
  efi_config {
    efi_storage_pool = var.proxmox_storage_pool
    efi_type         = "4m"
  }

  # SCSI Controller
  scsi_controller = "virtio-scsi-single"

  # Network
  network_adapters {
    model    = "virtio"
    bridge   = "vmbr0"
    firewall = false
  }

  # Disk
  disks {
    type         = "scsi"
    disk_size    = "20G"
    storage_pool = var.proxmox_storage_pool
    discard      = true
    io_thread    = true
  }

  # Boot commands for automated installation
  boot_command = [
    "<esc><wait>",
    "e<wait>",
    "<down><down><down><end>",
    "<bs><bs><bs><bs><wait>",
    "autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ---<wait>",
    "<f10><wait>"
  ]

  boot_wait      = "5s"
  http_directory = "http"

  # SSH for provisioning
  ssh_username               = "ubuntu"
  ssh_password               = "ubuntu"
  ssh_timeout                = "30m"
  ssh_handshake_attempts     = 100
  ssh_agent_auth             = false

  # Use cloud-init to get IP instead of QEMU agent
  vm_interface               = "enp6s18"

  # Template settings
  onboot = false

  # Tags for organization
  tags = "ubuntu;template;packer"
}

# Build configuration
build {
  sources = ["source.proxmox-iso.ubuntu_template"]

  # Configure template with Ansible
  provisioner "ansible" {
    playbook_file = "../../ansible/playbooks/packer-base-vm.yml"
    user          = "ubuntu"
  }
}
