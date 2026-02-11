resource "routeros_interface_bridge" "main" {
  name           = var.bridge_name
  vlan_filtering = true
  comment        = "VLAN-aware bridge for homelab infrastructure"
}

# Access ports: untagged on their PVID VLAN
# depends_on ensures VLAN memberships exist before ports join the filtered bridge
resource "routeros_interface_bridge_port" "access_ports" {
  for_each = var.access_ports

  interface = each.value.interface
  bridge    = routeros_interface_bridge.main.name
  pvid      = each.value.pvid
  comment   = each.value.comment

  depends_on = [routeros_interface_bridge_vlan.vlan_membership]
}

# Trunk ports: carry all VLANs tagged
resource "routeros_interface_bridge_port" "trunk_ports" {
  for_each = var.trunk_ports

  interface   = each.value.interface
  bridge      = routeros_interface_bridge.main.name
  pvid        = 1
  frame_types = "admit-only-vlan-tagged"
  comment     = each.value.comment

  depends_on = [routeros_interface_bridge_vlan.vlan_membership]
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

# WAN IP on ether1 (standalone, not in bridge)
resource "routeros_ip_address" "wan" {
  address   = var.wan_address
  interface = var.wan_interface
  comment   = "WAN to O2 Homespot"
}

# Default route to internet via O2 Homespot
resource "routeros_ip_route" "default" {
  dst_address = "0.0.0.0/0"
  gateway     = var.wan_gateway
  comment     = "Default route to internet via O2 Homespot"
}

# VLAN bridge membership: trunk ports tagged, access ports untagged on their VLAN
resource "routeros_interface_bridge_vlan" "vlan_membership" {
  for_each = var.vlans

  bridge   = routeros_interface_bridge.main.name
  vlan_ids = [each.value.id]
  tagged = concat(
    [routeros_interface_bridge.main.name],
    [for k, v in var.trunk_ports : v.interface]
  )
  untagged = [
    for k, v in var.access_ports : v.interface
    if v.pvid == each.value.id
  ]
  comment = "VLAN ${each.value.id} (${each.value.name})"
}
