# ==============================================================================
# TrueNAS SCALE VM - Backup Storage (Secondary Node)
# ==============================================================================
# Target: r630 (secondary node) - 192.168.0.10
# Network: Dual-homed (VLAN 10 storage + VLAN 20 management)
# Storage: MD1200 disk shelf (12× 3.5" bays) - configured manually in Proxmox UI
#
# Prerequisites:
# - Configure MD1200 HBA passthrough in Proxmox UI (Hardware > Add > PCI Device)
# - Create pool manually after TrueNAS installation:
#   - backup: 8×3TB Constellation RAIDZ2 (~18TB)
#
# Note: This creates the VM shell. Disk passthrough must be configured manually
# in Proxmox UI due to provider limitations.

resource "proxmox_virtual_environment_download_file" "truenas_backup_iso" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = local.proxmox_secondary
  url          = local.truenas_url
  file_name    = local.truenas_filename
  overwrite    = false
}

resource "proxmox_virtual_environment_vm" "truenas_backup" {
  name          = "truenas-backup"
  description   = "TrueNAS SCALE ${local.truenas_version} - Backup Storage on ${local.proxmox_secondary} (r630)"
  tags          = ["truenas", "storage", "nas", "backup"]
  node_name     = local.proxmox_secondary
  vm_id         = 301
  on_boot       = true
  bios          = "ovmf"
  machine       = "q35"
  scsi_hardware = "virtio-scsi-single"
  boot_order    = ["virtio0"]

  cpu {
    cores   = 2
    sockets = 1
    type    = "host"
    numa    = false
  }

  memory {
    dedicated = 8192
    floating  = 8192
  }

  operating_system {
    type = "l26"
  }

  vga {
    type   = "virtio"
    memory = 32
  }

  efi_disk {
    datastore_id      = "local-zfs"
    pre_enrolled_keys = false
    type              = "4m"
  }

  cdrom {
    file_id   = proxmox_virtual_environment_download_file.truenas_backup_iso.id
    interface = "ide2"
  }

  # Network 1: VLAN 20 (Management) - 192.168.0.14
  network_device {
    bridge      = "vmbr0"
    vlan_id     = 20
    mac_address = "BC:24:11:2E:D4:04"
    model       = "virtio"
  }

  # Network 2: VLAN 10 (Storage) - 10.10.10.14 (for replication over 10G DAC)
  network_device {
    bridge  = "vmbr0"
    vlan_id = 10
    model   = "virtio"
  }

  # Boot disk (OS only, ZFS pool on passed-through MD1200)
  disk {
    datastore_id = "local-zfs"
    file_format  = "raw"
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = 32
    ssd          = true
    cache        = "none"
  }

  initialization {
    ip_config {
      ipv4 {
        address = "192.168.0.14/24"
        gateway = "192.168.0.1"
      }
    }

    ip_config {
      ipv4 {
        address = "10.10.10.14/24"
      }
    }

    dns {
      servers = ["192.168.0.53"] # Pi-hole DNS
    }
  }

  lifecycle {
    ignore_changes = [
      cdrom,         # Allow manual ISO changes
      disk,          # Ignore MD1200 HBA passthrough disks added via UI
      hostpci,       # Ignore PCIe passthrough added via UI
      network_device # Ignore network config changes
    ]
  }

  depends_on = [proxmox_virtual_environment_download_file.truenas_backup_iso]
}

# Output for documentation
output "truenas_backup_management_ip" {
  value       = "192.168.0.14"
  description = "TrueNAS backup management interface (VLAN 20)"
}

output "truenas_backup_storage_ip" {
  value       = "10.10.10.14"
  description = "TrueNAS backup storage interface (VLAN 10)"
}

output "truenas_backup_vm_id" {
  value       = proxmox_virtual_environment_vm.truenas_backup.vm_id
  description = "Proxmox VM ID for TrueNAS backup"
}
