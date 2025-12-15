module "arr_server" {
  source = "../modules/ubuntu-vm"

  vm_name      = "arr-server"
  ssh_keys     = [var.ssh_public_key]
  ipv4_address = "192.168.1.50/24"
  ipv4_gateway = "192.168.1.1"
  cpu_cores    = 4
  memory_mb    = 8192
  disk_size_gb = 100
  tags         = ["media", "arr"]
}

resource "ansible_playbook" "arr_stack" {
  playbook   = "${path.module}/../../ansible/playbooks/stack-arr.yml"
  name       = module.arr_server.ipv4_addresses[0][0]
  replayable = true

  extra_vars = {
    ansible_user         = "ubuntu"
    ansible_become       = true
    timezone             = "Europe/Berlin"
    data_location        = "/opt/stacks/arr/data"
    media_location       = "/mnt/media"
    puid                 = "1000"
    pgid                 = "1000"
    vpn_provider         = "protonvpn"
    openvpn_user         = var.openvpn_user
    openvpn_password     = var.openvpn_password
    soulseek_username    = var.soulseek_username
    soulseek_password    = var.soulseek_password
    enable_observability = var.enable_observability
  }

  depends_on = [module.arr_server]
}
