# Generic Proxmox VM with support for UEFI, cloud-init, PCI passthrough, and dual networking.

locals {
  is_uefi     = var.boot_mode == "uefi"
  is_iso_boot = var.iso_id != null
}

resource "proxmox_virtual_environment_vm" "vm" {
  name        = var.vm_name
  description = var.vm_description
  tags        = var.tags
  pool_id     = var.pool_id
  node_name   = var.node_name
  vm_id       = var.vm_id
  on_boot     = var.start_on_boot
  bios        = local.is_uefi ? "ovmf" : "seabios"

  startup {
    order      = var.startup_order
    up_delay   = var.startup_up_delay
    down_delay = var.startup_down_delay
  }
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

  dynamic "efi_disk" {
    for_each = local.is_uefi ? [1] : []
    content {
      datastore_id      = var.boot_disk_storage
      pre_enrolled_keys = false
      type              = "4m"
    }
  }

  dynamic "cdrom" {
    for_each = local.is_iso_boot ? [1] : []
    content {
      file_id   = var.iso_id
      interface = "ide2"
    }
  }

  vga {
    type   = var.vga_type
    memory = var.vga_type != "none" ? 32 : 0
  }

  # Serial console (required when vga=none for GPU passthrough)
  dynamic "serial_device" {
    for_each = var.enable_serial_console ? [1] : []
    content {
      device = "socket"
    }
  }

  network_device {
    bridge      = var.network_bridge
    mac_address = var.mac_address
    vlan_id     = var.vlan_id
    model       = "virtio"
  }

  dynamic "network_device" {
    for_each = var.enable_dual_network ? [1] : []
    content {
      bridge  = var.secondary_bridge
      vlan_id = var.secondary_vlan_id
      model   = "virtio"
    }
  }

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

  dynamic "hostpci" {
    for_each = var.enable_pci_passthrough ? [1] : []
    content {
      device  = "hostpci0"
      mapping = var.pci_mapping_id
      pcie    = true
      rombar  = true
    }
  }

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

  dynamic "agent" {
    for_each = var.enable_qemu_agent ? [1] : []
    content {
      enabled = true
    }
  }

  # Ignore external changes (nixos-anywhere repartitions, CD-ROM ejected, manual HBA additions)
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
