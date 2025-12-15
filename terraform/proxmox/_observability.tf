module "observability_server" {
  source = "../modules/ubuntu-vm"

  vm_name      = "monitoring-server"
  ssh_keys     = [var.ssh_public_key]
  ipv4_address = "192.168.1.51/24"
  ipv4_gateway = "192.168.1.1"
  cpu_cores    = 2
  memory_mb    = 4096
  disk_size_gb = 50
  tags         = ["monitoring", "observability"]
}

resource "ansible_playbook" "observability_stack" {
  playbook   = "${path.module}/../../ansible/playbooks/stack-observability.yml"
  name       = module.observability_server.ipv4_addresses[0][0]
  replayable = true

  extra_vars = {
    ansible_user           = "ubuntu"
    ansible_become         = true
    data_location          = "/opt/stacks/observability/data"
    grafana_admin_password = var.grafana_admin_password
    exportarr_targets = jsonencode([
      "${module.arr_server.ipv4_addresses[0][0]}:9707",
      "${module.arr_server.ipv4_addresses[0][0]}:9708",
      "${module.arr_server.ipv4_addresses[0][0]}:9709",
      "${module.arr_server.ipv4_addresses[0][0]}:9710",
    ])
  }

  depends_on = [
    module.observability_server,
    ansible_playbook.arr_stack
  ]
}
