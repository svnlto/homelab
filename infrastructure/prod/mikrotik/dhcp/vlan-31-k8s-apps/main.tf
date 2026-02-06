resource "routeros_ip_pool" "dhcp" {
  name    = "dhcp-pool-${var.vlan_name}"
  ranges  = ["${var.dhcp_start}-${var.dhcp_end}"]
  comment = "DHCP pool for VLAN ${var.vlan_id} (${var.vlan_name})"
}

resource "routeros_ip_dhcp_server" "this" {
  name         = "dhcp-server-${var.vlan_name}"
  interface    = var.vlan_interface
  address_pool = routeros_ip_pool.dhcp.name
  lease_time   = var.dhcp_lease
  comment      = "DHCP server for ${var.vlan_name}"
}

resource "routeros_ip_dhcp_server_network" "this" {
  address    = var.subnet
  gateway    = var.gateway
  dns_server = var.dns_servers
  comment    = "DHCP network config for ${var.vlan_name}"
}
