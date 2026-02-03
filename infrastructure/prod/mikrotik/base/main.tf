resource "routeros_interface_bridge" "main" {
  name           = var.bridge_name
  vlan_filtering = true
  comment        = "VLAN-aware bridge for homelab infrastructure"
}

resource "routeros_interface_bridge_port" "trunk_ports" {
  for_each = var.interfaces

  interface = each.value
  bridge    = routeros_interface_bridge.main.name
  pvid      = 1
  comment   = "Trunk port: ${each.key}"
}

resource "routeros_interface_vlan" "vlans" {
  for_each = var.vlans

  name      = "vlan-${each.value.id}-${each.value.name}"
  vlan_id   = each.value.id
  interface = routeros_interface_bridge.main.name
  comment   = each.value.description
}

resource "routeros_ip_address" "vlan_gateways" {
  for_each = var.vlans

  address   = "${each.value.gateway}/24"
  interface = routeros_interface_vlan.vlans[each.key].name
  comment   = "Gateway for ${each.value.name} (${each.value.subnet})"
}

resource "routeros_ip_settings" "routing" {
  rp_filter = "loose"
}
