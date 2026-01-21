# =============================================================================
# Packer Template for Proxmox Node Image
# Uses QEMU builder with Ansible provisioner
# =============================================================================

packer {
  required_version = ">= 1.9.0"

  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = ">= 1.1.0"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = ">= 1.1.0"
    }
  }
}

# -----------------------------------------------------------------------------
# Local Variables
# -----------------------------------------------------------------------------
locals {
  timestamp    = formatdate("YYYYMMDD-hhmmss", timestamp())
  output_name  = "proxmox-node-${local.timestamp}"

  # Debian suite based on PVE version
  debian_suite = var.pve_version == "9" ? "trixie" : "bookworm"

  # Build Ansible extra vars
  ansible_extra_vars_merged = merge(
    {
      pve_version                  = var.pve_version
      pve_repository               = var.pve_repository
      pve_remove_subscription_warning = var.remove_subscription_warning
      install_cloud_init           = var.install_cloud_init
      install_zfs                  = var.install_zfs
      configure_pcie_passthrough   = var.configure_pcie_passthrough
      node_hostname                = var.hostname
      node_domain                  = var.domain
    },
    var.ansible_extra_vars
  )
}

# -----------------------------------------------------------------------------
# QEMU Builder Source
# -----------------------------------------------------------------------------
source "qemu" "proxmox-node" {
  # ISO configuration
  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum

  # VM naming and output
  vm_name          = local.output_name
  output_directory = "output/${local.output_name}"

  # Hardware configuration
  memory    = var.memory
  cpus      = var.cpus
  disk_size = var.disk_size

  # Virtualization settings
  accelerator = "tcg"
  machine_type = "q35"

  # UEFI configuration
  efi_boot          = var.efi_boot
  efi_firmware_code = var.efi_boot ? var.efi_firmware_code : null
  efi_firmware_vars = var.efi_boot ? var.efi_firmware_vars : null

  # Disk configuration
  format         = var.output_format
  disk_interface = "virtio-scsi"
  disk_cache     = "writeback"
  disk_discard   = "unmap"

  # Network configuration
  net_device       = "virtio-net"
  host_port_min    = 2222
  host_port_max    = 2229

  # Direct kernel boot - bypasses bootloader entirely
  qemuargs = [
    ["-serial", "file:output/${local.output_name}/serial.log"],
    ["-kernel", "/vagrant/boot-files/vmlinuz"],
    ["-initrd", "/vagrant/boot-files/initrd.gz"],
    ["-append", "auto=true url=http://10.0.2.2:8100/preseed.cfg hostname=${var.hostname} domain=${var.domain} interface=auto priority=critical console=ttyS0,115200n8 DEBIAN_FRONTEND=text"]
  ]

  # Display settings
  headless         = var.headless
  vnc_bind_address = "0.0.0.0"
  vnc_port_min     = 5900
  vnc_port_max     = 5900
  vnc_use_password = false

  # SSH settings
  ssh_username         = var.ssh_username
  ssh_password         = var.ssh_password
  ssh_timeout          = var.ssh_timeout
  ssh_port             = 22
  ssh_handshake_attempts = 100
  ssh_pty              = true

  # HTTP server for preseed
  http_directory = "http"
  http_port_min  = 8100
  http_port_max  = 8199

  # Boot configuration - using direct kernel boot (no boot_command needed)

  # Shutdown
  shutdown_command = "shutdown -P now"
  shutdown_timeout = "5m"
}

# -----------------------------------------------------------------------------
# Build Configuration
# -----------------------------------------------------------------------------
build {
  name    = "proxmox-node"
  sources = ["source.qemu.proxmox-node"]

  # Wait for system to settle after boot
  provisioner "shell" {
    inline = [
      "echo 'Waiting for system to settle...'",
      "sleep 10",
      "cloud-init status --wait 2>/dev/null || true"
    ]
  }

  # Install Python for Ansible (minimal bootstrap)
  provisioner "shell" {
    inline = [
      "apt-get update",
      "apt-get install -y python3 python3-apt"
    ]
  }

  # Main Ansible provisioning
  provisioner "ansible" {
    playbook_file = "/ansible/playbooks/packer-proxmox-node.yml"
    user          = var.ssh_username

    extra_arguments = [
      "--extra-vars", jsonencode(local.ansible_extra_vars_merged),
      "-v"
    ]

    ansible_env_vars = [
      "ANSIBLE_CONFIG=/ansible/ansible.cfg",
      "ANSIBLE_FORCE_COLOR=1",
      "ANSIBLE_HOST_KEY_CHECKING=False"
    ]

    # Use the built-in SSH connection from Packer
    use_proxy = false
  }

  # Final cleanup
  provisioner "shell" {
    inline = [
      "echo 'Final cleanup...'",
      "sync"
    ]
  }

  # Compress the output (only for raw format)
  post-processor "shell-local" {
    inline = [
      "if [ '${var.output_format}' = 'raw' ]; then",
      "  echo 'Compressing raw image...'",
      "  gzip -9 -k output/${local.output_name}/${local.output_name}",
      "  echo 'Compressed image: output/${local.output_name}/${local.output_name}.gz'",
      "fi",
      "echo 'Build complete: output/${local.output_name}/'"
    ]
  }

  # Generate build manifest
  post-processor "manifest" {
    output     = "output/${local.output_name}/manifest.json"
    strip_path = true
    custom_data = {
      build_timestamp = local.timestamp
      pve_version     = var.pve_version
      pve_repository  = var.pve_repository
      output_format   = var.output_format
    }
  }
}
