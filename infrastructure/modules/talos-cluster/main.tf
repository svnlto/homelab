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

  bios            = "ovmf"
  machine         = "q35"
  scsi_hardware   = "virtio-scsi-pci"
  boot_order      = ["scsi0"]
  stop_on_destroy = true

  cpu {
    cores = each.value.cpu_cores
    type  = "host"
    numa  = false
  }

  memory {
    dedicated = each.value.memory_mb
  }

  agent {
    enabled = false
  }

  vga {
    type   = "virtio"
    memory = 32
  }

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
    file_id      = var.talos_image_id
    ssd          = true
  }

  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  initialization {
    datastore_id = var.datastore_id
    ip_config {
      ipv4 {
        address = each.value.ip_address
        gateway = var.network_gateway
      }
    }
  }

}

# ==============================================================================
# Worker VMs
# ==============================================================================

resource "proxmox_virtual_environment_vm" "worker" {
  for_each = var.worker_nodes

  depends_on = [proxmox_virtual_environment_vm.control_plane]

  name        = each.value.hostname
  node_name   = each.value.node_name
  vm_id       = each.value.vm_id
  description = "Talos Worker - ${each.value.hostname}${each.value.gpu_passthrough ? " (GPU)" : ""} (${var.cluster_name})"
  tags = concat(["talos", "kubernetes", "worker", var.cluster_name, "terraform"],
  each.value.gpu_passthrough ? ["gpu"] : [], var.tags)
  on_boot = true
  started = true

  bios            = "ovmf"
  machine         = "q35"
  scsi_hardware   = "virtio-scsi-pci"
  boot_order      = ["scsi0"]
  stop_on_destroy = true

  cpu {
    cores = each.value.cpu_cores
    type  = "host"
    numa  = false
  }

  memory {
    dedicated = each.value.memory_mb
    floating  = 0
  }

  agent {
    enabled = false
  }

  dynamic "serial_device" {
    for_each = each.value.gpu_passthrough ? [1] : []

    content {
      device = "socket"
    }
  }

  vga {
    type   = each.value.gpu_passthrough ? "serial0" : "virtio"
    memory = 4
  }

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
    file_id      = var.talos_image_id
    ssd          = true
  }

  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  initialization {
    datastore_id = var.datastore_id
    ip_config {
      ipv4 {
        address = each.value.ip_address
        gateway = var.network_gateway
      }
    }
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

}

resource "talos_machine_configuration_apply" "control_plane" {
  for_each = var.control_plane_nodes

  client_configuration        = talos_machine_secrets.cluster.client_configuration
  machine_configuration_input = data.talos_machine_configuration.control_plane[each.key].machine_configuration

  # Connect to the DHCP-reserved IP (matches static IP in machine config)
  node     = split("/", each.value.ip_address)[0]
  endpoint = split("/", each.value.ip_address)[0]

  depends_on = [proxmox_virtual_environment_vm.control_plane]
}

resource "talos_machine_configuration_apply" "worker" {
  for_each = var.worker_nodes

  client_configuration        = talos_machine_secrets.cluster.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker[each.key].machine_configuration

  # Connect to the DHCP-reserved IP (matches static IP in machine config)
  node     = split("/", each.value.ip_address)[0]
  endpoint = split("/", each.value.ip_address)[0]

  depends_on = [proxmox_virtual_environment_vm.worker]
}

# ==============================================================================
# Bootstrap Cluster
# ==============================================================================

resource "talos_machine_bootstrap" "cluster" {
  count = var.deploy_bootstrap ? 1 : 0

  client_configuration = talos_machine_secrets.cluster.client_configuration
  endpoint             = split("/", values(var.control_plane_nodes)[0].ip_address)[0]
  node                 = split("/", values(var.control_plane_nodes)[0].ip_address)[0]

  depends_on = [talos_machine_configuration_apply.control_plane]
}

# ==============================================================================
# Cluster Health Gate — blocks until API, etcd, and all nodes are Ready
# ==============================================================================

data "talos_cluster_health" "cluster" {
  count = var.deploy_bootstrap ? 1 : 0

  client_configuration = talos_machine_secrets.cluster.client_configuration

  control_plane_nodes = [
    for node in values(var.control_plane_nodes) : split("/", node.ip_address)[0]
  ]

  worker_nodes = [
    for node in values(var.worker_nodes) : split("/", node.ip_address)[0]
  ]

  endpoints = [for node in values(var.control_plane_nodes) : split("/", node.ip_address)[0]]

  timeouts = {
    read = "10m"
  }

  depends_on = [
    talos_machine_bootstrap.cluster,
    talos_machine_configuration_apply.control_plane,
    talos_machine_configuration_apply.worker,
  ]
}

# ==============================================================================
# Retrieve Credentials
# ==============================================================================

resource "talos_cluster_kubeconfig" "cluster" {
  count = var.deploy_bootstrap ? 1 : 0

  client_configuration = talos_machine_secrets.cluster.client_configuration
  endpoint             = split("/", values(var.control_plane_nodes)[0].ip_address)[0]
  node                 = split("/", values(var.control_plane_nodes)[0].ip_address)[0]

  depends_on = [talos_machine_bootstrap.cluster]
}

resource "local_sensitive_file" "kubeconfig" {
  count = var.deploy_bootstrap ? 1 : 0

  content         = talos_cluster_kubeconfig.cluster[0].kubeconfig_raw
  filename        = "${path.cwd}/configs/kubeconfig-${var.cluster_name}"
  file_permission = "0600"
}

resource "local_sensitive_file" "talosconfig" {
  content         = data.talos_client_configuration.talosconfig.talos_config
  filename        = "${path.cwd}/configs/talosconfig-${var.cluster_name}"
  file_permission = "0600"
}
