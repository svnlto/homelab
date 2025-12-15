# =============================================================================
# Packer Template for Proxmox Node Image
# Uses cloud image + Ansible (no installer required)
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
  timestamp   = formatdate("YYYYMMDD-hhmmss", timestamp())
  output_name = "proxmox-node-${local.timestamp}"

  # Debian 12 Bookworm for PVE 8
  debian_suite   = "bookworm"
  debian_version = "12"

  # Cloud image URL
  cloud_image_url      = "https://cloud.debian.org/images/cloud/${local.debian_suite}/latest/debian-${local.debian_version}-generic-amd64.qcow2"
  cloud_image_checksum = "file:https://cloud.debian.org/images/cloud/${local.debian_suite}/latest/SHA512SUMS"

  # Build Ansible extra vars
  ansible_extra_vars_merged = merge(
    {
      pve_version                     = var.pve_version
      pve_repository                  = var.pve_repository
      pve_remove_subscription_warning = var.remove_subscription_warning
      install_cloud_init              = var.install_cloud_init
      install_zfs                     = var.install_zfs
      install_ceph                    = var.install_ceph
      configure_pcie_passthrough      = var.configure_pcie_passthrough
      node_hostname                   = var.hostname
      node_domain                     = var.domain
      proxmox_ssh_public_key          = var.proxmox_ssh_public_key
    },
    var.ansible_extra_vars
  )
}

# -----------------------------------------------------------------------------
# QEMU Builder Source - Cloud Image Based
# -----------------------------------------------------------------------------
source "qemu" "proxmox-node" {
  # Cloud image configuration (NOT an installer ISO)
  iso_url      = local.cloud_image_url
  iso_checksum = local.cloud_image_checksum
  disk_image   = true # KEY: Boot existing image, don't treat as installer

  # VM naming and output
  vm_name          = local.output_name
  output_directory = "output/${local.output_name}"

  # Hardware configuration
  memory    = var.memory
  cpus      = var.cpus
  disk_size = var.disk_size

  # Virtualization settings - TCG for x86 on ARM host
  accelerator  = "tcg"
  machine_type = "q35"

  # Use BIOS - simpler and faster than UEFI under emulation
  efi_boot = false

  # QEMU performance optimizations for TCG
  qemuargs = [
    ["-cpu", "max"],
    ["-smp", "cpus=${var.cpus},cores=${var.cpus},threads=1,sockets=1"]
  ]

  # Disk configuration
  format           = var.output_format
  disk_interface   = "virtio-scsi"
  disk_cache       = "writeback"
  disk_discard     = "unmap"
  disk_compression = true

  # Network configuration
  net_device    = "virtio-net"
  host_port_min = 2222
  host_port_max = 2229

  # Cloud-init seed ISO - provides initial configuration
  cd_files = [
    "${path.root}/cloud-init/user-data",
    "${path.root}/cloud-init/meta-data"
  ]
  cd_label = "cidata"

  # Display settings
  headless         = var.headless
  vnc_bind_address = "0.0.0.0"
  vnc_port_min     = 5900
  vnc_port_max     = 5900
  vnc_use_password = false

  # SSH settings
  ssh_username           = "root"
  ssh_password           = var.ssh_password
  ssh_timeout            = "20m"
  ssh_port               = 22
  ssh_handshake_attempts = 50
  ssh_pty                = true

  # No boot_command needed - cloud image boots directly

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

  # Wait for cloud-init to complete
  provisioner "shell" {
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "cloud-init status --wait || true",
      "echo 'Cloud-init finished.'"
    ]
  }

  # Install Python for Ansible
  provisioner "shell" {
    inline = [
      "apt-get update",
      "apt-get install -y --no-install-recommends python3 python3-apt python3-six sudo"
    ]
  }

  # Main Ansible provisioning - transforms Debian into Proxmox
  provisioner "ansible" {
    playbook_file = var.ansible_playbook

    extra_arguments = [
      "--extra-vars", jsonencode(merge(
        local.ansible_extra_vars_merged,
        {
          ansible_user                 = "root"
          ansible_password             = var.ssh_password
          ansible_ssh_common_args      = "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
        }
      )),
      "-vvv"
    ]

    ansible_env_vars = [
      "ANSIBLE_CONFIG=${var.ansible_config}",
      "ANSIBLE_FORCE_COLOR=1",
      "ANSIBLE_HOST_KEY_CHECKING=False"
    ]

    # Connect directly without proxy, using password auth
    use_proxy = false
  }

  # Final cleanup
  provisioner "shell" {
    inline = [
      "echo 'Final cleanup...'",
      "apt-get clean",
      "rm -rf /var/lib/apt/lists/*",
      "rm -rf /tmp/*",
      "cloud-init clean --logs || true",
      "sync"
    ]
  }

  # Compress raw images
  post-processor "shell-local" {
    inline = [
      "if [ '${var.output_format}' = 'raw' ]; then",
      "  echo 'Compressing raw image...'",
      "  gzip -9 -k output/${local.output_name}/${local.output_name}",
      "  echo 'Compressed: output/${local.output_name}/${local.output_name}.gz'",
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
      base_image      = "debian-${local.debian_version}-cloud-amd64"
    }
  }
}
