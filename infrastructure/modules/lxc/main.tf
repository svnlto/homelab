# ==============================================================================
# LXC Container Module - Main Configuration
# ==============================================================================

resource "proxmox_virtual_environment_container" "container" {
  description   = var.container_description
  node_name     = var.node_name
  tags          = var.tags
  pool_id       = var.pool_id
  vm_id         = var.container_id
  unprivileged  = var.unprivileged
  start_on_boot = true

  startup {
    order      = 2
    up_delay   = 30
    down_delay = 30
  }

  operating_system {
    template_file_id = var.template_file_id
    type             = "nixos"
  }

  cpu {
    cores = var.cores
  }

  memory {
    dedicated = var.memory_mb
  }

  dynamic "features" {
    for_each = var.unprivileged ? [1] : []
    content {
      nesting = true
    }
  }

  disk {
    datastore_id = "local-zfs"
    size         = var.disk_size_gb
  }

  # Primary network interface (LAN)
  network_interface {
    name   = "eth0"
    bridge = var.network_bridge
  }

  # Secondary network interface (storage VLAN)
  dynamic "network_interface" {
    for_each = var.secondary_bridge != null ? [1] : []
    content {
      name   = "eth1"
      bridge = var.secondary_bridge
    }
  }

  initialization {
    hostname = var.container_name

    ip_config {
      ipv4 {
        address = var.ip_address
        gateway = var.gateway
      }
    }

    dynamic "ip_config" {
      for_each = var.storage_ip != null ? [1] : []
      content {
        ipv4 {
          address = var.storage_ip
        }
      }
    }

    dns {
      servers = var.dns_servers
    }
  }

  # Lifecycle - ignore manual changes made in Proxmox UI
  lifecycle {
    ignore_changes = [
      network_interface, # Network changes made manually
    ]
  }
}
