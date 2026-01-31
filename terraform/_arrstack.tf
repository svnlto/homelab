# Arr Stack - Single LXC Container Running Full Media Automation Stack
# Provisions with ansible/roles/arr for complete orchestration

resource "proxmox_virtual_environment_container" "arr_stack" {
  node_name     = var.proxmox_node
  vm_id         = 200
  description   = "Arr Media Stack - Full automation suite (Terraform managed)"
  tags          = ["arr", "media", "terraform"]
  unprivileged  = true
  start_on_boot = true

  cpu {
    cores = 4
  }

  memory {
    dedicated = 4096 # 4GB for full stack
    swap      = 512
  }

  disk {
    datastore_id = "local-lvm"
    size         = 50 # Config and temporary data
  }

  operating_system {
    # Debian 12 template must be downloaded first:
    # pveam update && pveam download local debian-12-standard_12.2-1_amd64.tar.zst
    template_file_id = "local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst"
    type             = "debian"
  }

  network_interface {
    name   = "eth0"
    bridge = "vmbr0"
  }

  features {
    nesting = true # Required for Docker Compose
  }

  # Shared media storage mount (NFS from TrueNAS)
  mount_point {
    volume = "/mnt/pve/media" # Must be mounted on Proxmox host
    path   = "/mnt/media"
    shared = true
  }

  initialization {
    hostname = "arr-stack"

    ip_config {
      ipv4 {
        address = "192.168.0.200/24"
        gateway = "192.168.0.1"
      }
    }

    dns {
      servers = ["192.168.0.53"] # Pi-hole
    }

    user_account {
      keys = [trimspace(var.ssh_public_key)]
    }
  }

  lifecycle {
    ignore_changes = [
      initialization[0].user_account
    ]
  }
}

# Provision arr stack using the comprehensive arr role
resource "terraform_data" "arr_provisioning" {
  triggers_replace = [
    proxmox_virtual_environment_container.arr_stack.id
  ]

  # Wait for container to be ready and install Python
  provisioner "local-exec" {
    command = <<-EOT
      sleep 30
      ssh -o StrictHostKeyChecking=no root@192.168.0.200 'apt-get update && apt-get install -y python3 python3-apt'
    EOT
  }

  # Deploy full arr stack using existing role
  provisioner "local-exec" {
    command = <<-EOT
      cd ${path.module}/../ansible
      ansible-playbook playbooks/stack-arr.yml \
        --inventory "192.168.0.200," \
        --extra-vars "ansible_user=root" \
        --extra-vars "ansible_become=false" \
        --extra-vars "puid=${var.puid}" \
        --extra-vars "pgid=${var.pgid}" \
        --extra-vars "timezone=Europe/Berlin" \
        --extra-vars "data_location=/opt/stacks/arr/data" \
        --extra-vars "media_location=/mnt/media" \
        --extra-vars "openvpn_user=${var.openvpn_user}" \
        --extra-vars "openvpn_password=${var.openvpn_password}" \
        --extra-vars "soulseek_username=${var.soulseek_username}" \
        --extra-vars "soulseek_password=${var.soulseek_password}"
    EOT
  }

  depends_on = [proxmox_virtual_environment_container.arr_stack]
}
