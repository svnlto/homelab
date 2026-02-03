resource "proxmox_virtual_environment_download_file" "truenas_iso" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = local.proxmox_primary
  url          = local.truenas_url
  file_name    = local.truenas_filename
  overwrite    = false
}

resource "proxmox_virtual_environment_vm" "truenas" {
  name          = "truenas-server"
  description   = "TrueNAS SCALE ${local.truenas_version} - Network Attached Storage"
  tags          = ["truenas", "storage", "nas"]
  node_name     = local.proxmox_primary
  vm_id         = 300
  on_boot       = true
  bios          = "ovmf"
  machine       = "q35"
  scsi_hardware = "virtio-scsi-single"
  boot_order    = ["virtio0"]

  cpu {
    cores   = 4
    sockets = 1
    type    = "host"
    numa    = false
  }

  memory {
    dedicated = 32768
    floating  = 32768
  }

  operating_system {
    type = "l26"
  }

  efi_disk {
    datastore_id      = "local-zfs"
    pre_enrolled_keys = false
    type              = "4m"
  }

  cdrom {
    file_id   = proxmox_virtual_environment_download_file.truenas_iso.id
    interface = "ide2"
  }

  network_device {
    bridge      = "vmbr0"
    mac_address = "BC:24:11:2E:D4:03"
    model       = "virtio"
  }

  vga {
    type   = "virtio"
    memory = 32
  }

  hostpci {
    device  = "hostpci0"
    mapping = "truenas-h330"
    pcie    = true
    rombar  = true
  }

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

  depends_on = [proxmox_virtual_environment_download_file.truenas_iso]
}
