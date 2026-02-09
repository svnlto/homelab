# ==============================================================================
# Generic VM Module - Main Configuration
# ==============================================================================

locals {
  is_uefi     = var.boot_mode == "uefi"
  is_iso_boot = var.iso_id != null
}

resource "proxmox_virtual_environment_vm" "vm" {
  name          = var.vm_name
  description   = var.vm_description
  tags          = var.tags
  pool_id       = var.pool_id
  node_name     = var.node_name
  vm_id         = var.vm_id
  on_boot       = var.start_on_boot
  bios          = local.is_uefi ? "ovmf" : "seabios"
  machine       = local.is_uefi ? "q35" : "i440fx"
  scsi_hardware = "virtio-scsi-single"
  boot_order    = ["virtio0"]

  cpu {
    cores   = var.cpu_cores
    sockets = var.cpu_sockets
    type    = var.cpu_type
    numa    = false
  }

  memory {
    dedicated = var.memory_mb
    floating  = var.memory_mb
  }

  operating_system {
    type = "l26"
  }

  # UEFI firmware disk
  dynamic "efi_disk" {
    for_each = local.is_uefi ? [1] : []
    content {
      datastore_id      = var.boot_disk_storage
      pre_enrolled_keys = false
      type              = "4m"
    }
  }

  # ISO boot media
  dynamic "cdrom" {
    for_each = local.is_iso_boot ? [1] : []
    content {
      file_id   = var.iso_id
      interface = "ide2"
    }
  }

  vga {
    type   = "virtio"
    memory = 32
  }

  # Primary network interface
  network_device {
    bridge      = var.network_bridge
    mac_address = var.mac_address
    vlan_id     = var.vlan_id
    model       = "virtio"
  }

  # Optional second network interface
  dynamic "network_device" {
    for_each = var.enable_dual_network ? [1] : []
    content {
      bridge  = var.secondary_bridge
      vlan_id = var.secondary_vlan_id
      model   = "virtio"
    }
  }

  # Boot disk (ISO install: empty disk; disk image: pre-loaded)
  disk {
    datastore_id = var.boot_disk_storage
    file_format  = "raw"
    file_id      = var.disk_image_id
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = var.boot_disk_size_gb
    ssd          = true
    cache        = "none"
  }

  # Additional data disks
  dynamic "disk" {
    for_each = var.additional_disks
    content {
      datastore_id = var.boot_disk_storage
      file_format  = "raw"
      interface    = "virtio${disk.key + 1}"
      iothread     = true
      discard      = "on"
      size         = disk.value
      ssd          = true
      cache        = "none"
    }
  }

  # Optional PCI passthrough
  dynamic "hostpci" {
    for_each = var.enable_pci_passthrough ? [1] : []
    content {
      device  = "hostpci0"
      mapping = var.pci_mapping_id
      pcie    = true
      rombar  = true
    }
  }

  # Optional cloud-init
  dynamic "initialization" {
    for_each = var.enable_cloud_init ? [1] : []
    content {
      ip_config {
        ipv4 {
          address = var.ip_address
          gateway = var.gateway
        }
      }

      dns {
        servers = var.nameserver != null ? [var.nameserver] : []
      }

      dynamic "user_account" {
        for_each = var.username != null ? [1] : []
        content {
          username = var.username
          keys     = var.ssh_keys
        }
      }
    }
  }

  # QEMU guest agent
  dynamic "agent" {
    for_each = var.enable_qemu_agent ? [1] : []
    content {
      enabled = true
    }
  }

  # Lifecycle - ignore changes made outside Terraform
  # (nixos-anywhere repartitions disk, CD-ROM removed after install, manual HBA additions)
  lifecycle {
    ignore_changes = [
      cdrom,
      disk,
      boot_order,
      network_device,
      hostpci,
    ]
  }
}
