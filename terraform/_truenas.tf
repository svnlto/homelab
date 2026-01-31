resource "proxmox_virtual_environment_download_file" "truenas_iso" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = "pve"
  url          = "https://download.sys.truenas.net/TrueNAS-SCALE-Dragonfish/24.04.2.5/TrueNAS-SCALE-24.04.2.5.iso"
  file_name    = "TrueNAS-SCALE-24.04.2.5.iso"
  overwrite    = false
}

resource "proxmox_virtual_environment_vm" "truenas" {
  name          = "truenas-server"
  description   = "TrueNAS SCALE 24.04.2.5 - Network Attached Storage"
  tags          = ["truenas", "storage", "nas"]
  node_name     = "pve"
  vm_id         = 300
  on_boot       = true
  bios          = "ovmf"
  machine       = "q35"
  scsi_hardware = "virtio-scsi-single"
  boot_order    = ["virtio0"]

  cpu {
    cores   = 4
    sockets = 1
    type    = "kvm64"
    numa    = false
  }

  memory {
    dedicated = 16384
  }

  operating_system {
    type = "l26"
  }

  vga {
    type   = "std"
    memory = 16
  }

  efi_disk {
    datastore_id      = "local-lvm"
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

  disk {
    datastore_id = "local-lvm"
    file_format  = "raw"
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = 32
    ssd          = true
    cache        = "none"
  }

  disk {
    datastore_id = "local-lvm"
    file_format  = "raw"
    interface    = "scsi1"
    iothread     = false
    discard      = "on"
    size         = 100
    ssd          = true
    cache        = "none"
  }

  disk {
    datastore_id = "local-lvm"
    file_format  = "raw"
    interface    = "scsi2"
    iothread     = false
    discard      = "on"
    size         = 100
    ssd          = true
    cache        = "none"
  }

  disk {
    datastore_id = "local-lvm"
    file_format  = "raw"
    interface    = "scsi3"
    iothread     = false
    discard      = "on"
    size         = 100
    ssd          = true
    cache        = "none"
  }

  depends_on = [proxmox_virtual_environment_download_file.truenas_iso]
}
