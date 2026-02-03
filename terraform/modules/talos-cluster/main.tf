# ==============================================================================
# Talos Image Factory Schematic
# ==============================================================================

resource "talos_image_factory_schematic" "this" {
  schematic = yamlencode({
    customization = {
      systemExtensions = {
        officialExtensions = data.talos_image_factory_extensions_versions.this.extensions_info[*].name
      }
    }
  })
}

# ==============================================================================
# Download Talos NoCloud Image
# ==============================================================================

resource "proxmox_virtual_environment_download_file" "talos_nocloud_image" {
  content_type = "iso"
  datastore_id = var.iso_datastore_id
  node_name    = var.proxmox_node_storage
  url          = "https://factory.talos.dev/image/${talos_image_factory_schematic.this.id}/${var.talos_version}/nocloud-amd64.raw.xz"
  file_name    = "talos-${talos_image_factory_schematic.this.id}-${var.talos_version}-nocloud-amd64.img"
  overwrite    = false
}

# ==============================================================================
# Talos Machine Secrets
# ==============================================================================

resource "talos_machine_secrets" "cluster" {
  talos_version = var.talos_version
}

# ==============================================================================
# Control Plane VMs
# ==============================================================================

resource "proxmox_virtual_environment_vm" "control_plane" {
  for_each = var.control_plane_nodes

  name        = each.value.hostname
  node_name   = each.value.node_name
  vm_id       = each.value.vm_id
  description = "Talos Control Plane - ${each.value.hostname} (${var.cluster_name})"
  tags        = concat(["talos", "kubernetes", "control-plane", var.cluster_name, "terraform"], var.tags)
  on_boot     = true

  bios          = "ovmf"
  machine       = "q35"
  scsi_hardware = "virtio-scsi-single"
  boot_order    = ["scsi0"]

  cpu {
    cores = each.value.cpu_cores
    type  = "host"
    numa  = false
  }

  memory {
    dedicated = each.value.memory_mb
    floating  = each.value.memory_mb
  }

  agent {
    enabled = true
    trim    = true
    type    = "virtio"
  }

  vga {
    type   = "virtio"
    memory = 32
  }

  serial_device {}

  efi_disk {
    datastore_id      = var.datastore_id
    pre_enrolled_keys = false
    type              = "4m"
  }

  disk {
    datastore_id = var.datastore_id
    interface    = "scsi0"
    size         = each.value.disk_size_gb
    file_format  = "raw"
    iothread     = true
    ssd          = true
  }

  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  cdrom {
    enabled   = true
    file_id   = proxmox_virtual_environment_download_file.talos_nocloud_image.id
    interface = "ide0"
  }

  initialization {
    ip_config {
      ipv4 {
        address = each.value.ip_address
        gateway = var.network_gateway
      }
    }

    dns {
      servers = var.dns_servers
    }
  }

  lifecycle {
    ignore_changes = [cdrom]
  }

  depends_on = [proxmox_virtual_environment_download_file.talos_nocloud_image]
}

# ==============================================================================
# Worker VMs
# ==============================================================================

resource "proxmox_virtual_environment_vm" "worker" {
  for_each = var.worker_nodes

  name        = each.value.hostname
  node_name   = each.value.node_name
  vm_id       = each.value.vm_id
  description = "Talos Worker - ${each.value.hostname}${each.value.gpu_passthrough ? " (GPU)" : ""} (${var.cluster_name})"
  tags = concat(["talos", "kubernetes", "worker", var.cluster_name, "terraform"],
  each.value.gpu_passthrough ? ["gpu"] : [], var.tags)
  on_boot = true

  bios          = "ovmf"
  machine       = "q35"
  scsi_hardware = "virtio-scsi-single"
  boot_order    = ["scsi0"]

  cpu {
    cores = each.value.cpu_cores
    type  = "host"
    numa  = false
  }

  memory {
    dedicated = each.value.memory_mb
    floating  = each.value.memory_mb
  }

  agent {
    enabled = true
    trim    = true
    type    = "virtio"
  }

  vga {
    type   = "virtio"
    memory = 32
  }

  serial_device {}

  efi_disk {
    datastore_id      = var.datastore_id
    pre_enrolled_keys = false
    type              = "4m"
  }

  disk {
    datastore_id = var.datastore_id
    interface    = "scsi0"
    size         = each.value.disk_size_gb
    file_format  = "raw"
    iothread     = true
    ssd          = true
  }

  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  dynamic "hostpci" {
    for_each = each.value.gpu_passthrough ? [1] : []

    content {
      device  = "hostpci0"
      mapping = each.value.gpu_mapping_id
      pcie    = true
      rombar  = true
      xvga    = false
    }
  }

  cdrom {
    enabled   = true
    file_id   = proxmox_virtual_environment_download_file.talos_nocloud_image.id
    interface = "ide0"
  }

  initialization {
    ip_config {
      ipv4 {
        address = each.value.ip_address
        gateway = var.network_gateway
      }
    }

    dns {
      servers = var.dns_servers
    }
  }

  lifecycle {
    ignore_changes = [cdrom]
  }

  depends_on = [proxmox_virtual_environment_download_file.talos_nocloud_image]
}

resource "talos_machine_configuration_apply" "control_plane" {
  for_each = var.control_plane_nodes

  client_configuration        = talos_machine_secrets.cluster.client_configuration
  machine_configuration_input = data.talos_machine_configuration.control_plane[each.key].machine_configuration

  node     = split("/", each.value.ip_address)[0]
  endpoint = split("/", each.value.ip_address)[0]

  depends_on = [proxmox_virtual_environment_vm.control_plane]
}

resource "talos_machine_configuration_apply" "worker" {
  for_each = var.worker_nodes

  client_configuration        = talos_machine_secrets.cluster.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker[each.key].machine_configuration

  node     = split("/", each.value.ip_address)[0]
  endpoint = split("/", each.value.ip_address)[0]

  depends_on = [proxmox_virtual_environment_vm.worker]
}

# ==============================================================================
# Bootstrap Cluster
# ==============================================================================

resource "talos_machine_bootstrap" "cluster" {
  client_configuration = talos_machine_secrets.cluster.client_configuration
  endpoint             = split("/", values(var.control_plane_nodes)[0].ip_address)[0]
  node                 = split("/", values(var.control_plane_nodes)[0].ip_address)[0]

  depends_on = [talos_machine_configuration_apply.control_plane]
}

# ==============================================================================
# Retrieve Credentials
# ==============================================================================

resource "talos_cluster_kubeconfig" "cluster" {
  client_configuration = talos_machine_secrets.cluster.client_configuration
  endpoint             = var.cluster_endpoint
  node                 = split("/", values(var.control_plane_nodes)[0].ip_address)[0]

  depends_on = [talos_machine_bootstrap.cluster]
}

resource "local_sensitive_file" "kubeconfig" {
  content         = talos_cluster_kubeconfig.cluster.kubeconfig_raw
  filename        = "${path.root}/../kubeconfig-${var.cluster_name}"
  file_permission = "0600"
}

resource "local_sensitive_file" "talosconfig" {
  content         = data.talos_client_configuration.talosconfig.talos_config
  filename        = "${path.root}/../talosconfig-${var.cluster_name}"
  file_permission = "0600"
}
