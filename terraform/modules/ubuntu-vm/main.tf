resource "proxmox_virtual_environment_vm" "this" {
  name        = var.vm_name
  node_name   = var.node_name
  description = var.description
  on_boot     = var.start_on_boot

  bios          = "ovmf"
  machine       = "q35"
  scsi_hardware = "virtio-scsi-single"
  boot_order    = ["scsi0"]

  tags = concat(["ubuntu", "terraform"], var.tags)

  clone {
    vm_id = var.template_vm_id
    full  = true
  }

  cpu {
    cores = var.cpu_cores
    type  = var.cpu_type
  }

  memory {
    dedicated = var.memory_mb
    floating  = var.memory_mb
  }

  agent {
    enabled = true
  }

  dynamic "vga" {
    for_each = var.vga_type != null || var.vga_memory != null ? [1] : []

    content {
      type   = var.vga_type != null ? var.vga_type : "std"
      memory = var.vga_memory
    }
  }

  efi_disk {
    datastore_id      = var.datastore_id
    pre_enrolled_keys = false
    type              = "4m"
  }

  disk {
    datastore_id = var.datastore_id
    interface    = "scsi0"
    size         = var.disk_size_gb
    file_format  = "raw"
  }

  network_device {
    bridge   = var.network_bridge
    model    = "virtio"
    firewall = var.network_firewall
  }

  dynamic "hostpci" {
    for_each = var.gpu_passthrough_enabled ? [1] : []

    content {
      device  = "hostpci0"
      mapping = var.gpu_mapping_id
      pcie    = true
      rombar  = true
      xvga    = false
    }
  }

  initialization {
    datastore_id = var.datastore_id

    ip_config {
      ipv4 {
        address = var.ipv4_address
        gateway = var.ipv4_gateway
      }
    }

    user_account {
      username = var.vm_user
      keys     = var.ssh_keys
    }

    dns {
      servers = var.dns_servers
    }
  }

  lifecycle {
    ignore_changes = [
      network_device,
    ]
  }
}

# Optional Ansible provisioning
resource "ansible_playbook" "provision" {
  count = var.ansible_playbook != null ? 1 : 0

  playbook   = var.ansible_playbook
  name       = try(proxmox_virtual_environment_vm.this.ipv4_addresses[0][0], proxmox_virtual_environment_vm.this.name)
  replayable = true

  extra_vars = merge(
    {
      ansible_user               = coalesce(var.ansible_user, var.vm_user)
      ansible_host               = try(proxmox_virtual_environment_vm.this.ipv4_addresses[0][0], "")
      ansible_connection         = "ssh"
      ansible_python_interpreter = "/usr/bin/python3"
    },
    var.ansible_extra_vars
  )
}
