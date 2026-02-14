# TrueNAS VM with HBA passthrough and dual networking (management + storage).

resource "proxmox_virtual_environment_vm" "truenas" {
  name        = var.vm_name
  description = "${var.vm_description} - TrueNAS SCALE ${var.truenas_version}"
  tags        = var.tags
  pool_id     = var.pool_id
  node_name   = var.node_name
  vm_id       = var.vm_id
  on_boot     = true
  bios        = "ovmf"

  startup {
    order      = 1
    up_delay   = 120
    down_delay = 120
  }
  machine       = "q35"
  scsi_hardware = "virtio-scsi-single"
  boot_order    = ["virtio0"]

  cpu {
    cores   = var.cpu_cores
    sockets = 1
    type    = "host"
    numa    = false
  }

  memory {
    dedicated = var.memory_mb
    floating  = var.memory_mb
  }

  operating_system {
    type = "l26"
  }

  efi_disk {
    datastore_id      = var.boot_disk_storage
    pre_enrolled_keys = false
    type              = "4m"
  }

  cdrom {
    file_id   = var.iso_id
    interface = "ide2"
  }

  vga {
    type   = "virtio"
    memory = 32
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
      bridge = var.storage_bridge
      model  = "virtio"
    }
  }

  disk {
    datastore_id = "local-zfs"
    file_format  = "raw"
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = var.boot_disk_size_gb
    ssd          = true
    cache        = "none"
  }

  # Optional HBA passthrough
  dynamic "hostpci" {
    for_each = var.enable_hostpci ? [1] : []
    content {
      device  = "hostpci0"
      mapping = var.hostpci_mapping
      pcie    = true
      rombar  = true
    }
  }

  # Optional network initialization
  dynamic "initialization" {
    for_each = var.enable_network_init ? [1] : []
    content {
      ip_config {
        ipv4 {
          address = var.management_ip
          gateway = var.management_gateway
        }
      }

      dynamic "ip_config" {
        for_each = var.enable_dual_network ? [1] : []
        content {
          ipv4 {
            address = var.storage_ip
          }
        }
      }

      dns {
        servers = [var.dns_server]
      }
    }
  }

  # Ignore manual changes (ejected ISO, HBA devices added in UI)
  lifecycle {
    ignore_changes = [
      cdrom,
      disk,
      hostpci,
      network_device,
    ]
  }
}
