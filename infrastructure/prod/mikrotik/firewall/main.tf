locals {
  zones = {
    wan        = [var.wan_interface]
    lan        = [var.vlan_interfaces["lan"]]
    management = [var.vlan_interfaces["management"]]
    storage    = [var.vlan_interfaces["storage"]]
    k8s = [
      var.vlan_interfaces["k8s_shared"],
      var.vlan_interfaces["k8s_apps"],
      var.vlan_interfaces["k8s_test"]
    ]
  }
}

resource "routeros_interface_list" "zones" {
  for_each = local.zones

  name    = each.key
  comment = "Firewall zone: ${each.key}"
}

resource "routeros_interface_list_member" "zone_members" {
  for_each = merge([
    for zone, ifaces in local.zones : {
      for iface in ifaces : "${zone}-${iface}" => {
        list      = zone
        interface = iface
      }
    }
  ]...)

  list      = routeros_interface_list.zones[each.value.list].name
  interface = each.value.interface
  comment   = "Member of ${each.value.list} zone"
}

# =============================================================================
# Input chain — protect the router itself (internet-facing)
# =============================================================================

resource "routeros_firewall_filter" "input_accept_established" {
  chain            = "input"
  action           = "accept"
  connection_state = "established,related"
  comment          = "Accept established/related input connections"

  lifecycle { create_before_destroy = true }
}

resource "routeros_firewall_filter" "input_drop_invalid" {
  chain            = "input"
  action           = "drop"
  connection_state = "invalid"
  comment          = "Drop invalid input packets"

  lifecycle { create_before_destroy = true }
}

resource "routeros_firewall_filter" "input_accept_lan" {
  chain             = "input"
  action            = "accept"
  in_interface_list = routeros_interface_list.zones["lan"].name
  comment           = "Accept input from LAN"

  lifecycle { create_before_destroy = true }
}

resource "routeros_firewall_filter" "input_accept_k8s" {
  chain             = "input"
  action            = "accept"
  in_interface_list = routeros_interface_list.zones["k8s"].name
  comment           = "Accept input from K8s (DHCP, DNS)"

  lifecycle { create_before_destroy = true }
}

resource "routeros_firewall_filter" "input_accept_management" {
  chain             = "input"
  action            = "accept"
  in_interface_list = routeros_interface_list.zones["management"].name
  comment           = "Accept input from management"

  lifecycle { create_before_destroy = true }
}

resource "routeros_firewall_filter" "input_accept_storage" {
  chain             = "input"
  action            = "accept"
  in_interface_list = routeros_interface_list.zones["storage"].name
  comment           = "Accept input from storage"

  lifecycle { create_before_destroy = true }
}

resource "routeros_firewall_filter" "input_accept_icmp" {
  chain    = "input"
  action   = "accept"
  protocol = "icmp"
  comment  = "Accept ICMP (ping)"

  lifecycle { create_before_destroy = true }
}

resource "routeros_firewall_filter" "input_drop_wan" {
  chain             = "input"
  action            = "drop"
  in_interface_list = routeros_interface_list.zones["wan"].name
  comment           = "Drop all other WAN input"

  lifecycle { create_before_destroy = true }
}

# =============================================================================
# Forward chain — inter-VLAN and internet-bound traffic
# =============================================================================

resource "routeros_firewall_filter" "accept_established" {
  chain            = "forward"
  action           = "accept"
  connection_state = "established,related"
  comment          = "Accept established/related connections"

  lifecycle { create_before_destroy = true }
}

resource "routeros_firewall_filter" "drop_invalid" {
  chain            = "forward"
  action           = "drop"
  connection_state = "invalid"
  comment          = "Drop invalid connections"

  lifecycle { create_before_destroy = true }
}

resource "routeros_firewall_filter" "lan_to_any" {
  chain             = "forward"
  action            = "accept"
  in_interface_list = routeros_interface_list.zones["lan"].name
  comment           = "LAN can access everything"

  lifecycle { create_before_destroy = true }
}

resource "routeros_firewall_filter" "k8s_to_storage" {
  chain              = "forward"
  action             = "accept"
  in_interface_list  = routeros_interface_list.zones["k8s"].name
  out_interface_list = routeros_interface_list.zones["storage"].name
  comment            = "K8s clusters can access storage"

  lifecycle { create_before_destroy = true }
}

resource "routeros_firewall_filter" "k8s_to_wan" {
  chain              = "forward"
  action             = "accept"
  in_interface_list  = routeros_interface_list.zones["k8s"].name
  out_interface_list = routeros_interface_list.zones["wan"].name
  comment            = "K8s clusters can access internet"

  lifecycle { create_before_destroy = true }
}

resource "routeros_firewall_filter" "k8s_isolation" {
  chain              = "forward"
  action             = "drop"
  in_interface_list  = routeros_interface_list.zones["k8s"].name
  out_interface_list = routeros_interface_list.zones["k8s"].name
  comment            = "Isolate K8s clusters from each other"

  lifecycle { create_before_destroy = true }
}

resource "routeros_firewall_filter" "mgmt_to_wan" {
  chain              = "forward"
  action             = "accept"
  in_interface_list  = routeros_interface_list.zones["management"].name
  out_interface_list = routeros_interface_list.zones["wan"].name
  comment            = "Management can access internet"

  lifecycle { create_before_destroy = true }
}

resource "routeros_firewall_filter" "storage_to_wan" {
  chain              = "forward"
  action             = "accept"
  in_interface_list  = routeros_interface_list.zones["storage"].name
  out_interface_list = routeros_interface_list.zones["wan"].name
  comment            = "Storage can access internet"

  lifecycle { create_before_destroy = true }
}

resource "routeros_firewall_filter" "default_drop" {
  chain   = "forward"
  action  = "drop"
  comment = "Default deny all other traffic"

  lifecycle { create_before_destroy = true }
}

# =============================================================================
# Rule ordering — ensures correct sequence survives updates/recreations
# =============================================================================

resource "routeros_move_items" "filter_rules" {
  resource_path = "/ip/firewall/filter"
  sequence = [
    # Input chain (order matters — evaluated top-to-bottom)
    routeros_firewall_filter.input_accept_established.id,
    routeros_firewall_filter.input_drop_invalid.id,
    routeros_firewall_filter.input_accept_lan.id,
    routeros_firewall_filter.input_accept_k8s.id,
    routeros_firewall_filter.input_accept_management.id,
    routeros_firewall_filter.input_accept_storage.id,
    routeros_firewall_filter.input_accept_icmp.id,
    routeros_firewall_filter.input_drop_wan.id,
    # Forward chain
    routeros_firewall_filter.accept_established.id,
    routeros_firewall_filter.drop_invalid.id,
    routeros_firewall_filter.lan_to_any.id,
    routeros_firewall_filter.k8s_to_storage.id,
    routeros_firewall_filter.k8s_to_wan.id,
    routeros_firewall_filter.k8s_isolation.id,
    routeros_firewall_filter.mgmt_to_wan.id,
    routeros_firewall_filter.storage_to_wan.id,
    routeros_firewall_filter.default_drop.id,
  ]

  depends_on = [
    routeros_firewall_filter.input_accept_established,
    routeros_firewall_filter.input_drop_invalid,
    routeros_firewall_filter.input_accept_lan,
    routeros_firewall_filter.input_accept_k8s,
    routeros_firewall_filter.input_accept_management,
    routeros_firewall_filter.input_accept_storage,
    routeros_firewall_filter.input_accept_icmp,
    routeros_firewall_filter.input_drop_wan,
    routeros_firewall_filter.accept_established,
    routeros_firewall_filter.drop_invalid,
    routeros_firewall_filter.lan_to_any,
    routeros_firewall_filter.k8s_to_storage,
    routeros_firewall_filter.k8s_to_wan,
    routeros_firewall_filter.k8s_isolation,
    routeros_firewall_filter.mgmt_to_wan,
    routeros_firewall_filter.storage_to_wan,
    routeros_firewall_filter.default_drop,
  ]
}

# Source NAT - Masquerade outbound traffic to internet
resource "routeros_ip_firewall_nat" "masquerade" {
  chain         = "srcnat"
  action        = "masquerade"
  out_interface = var.wan_interface
  comment       = "Masquerade outbound traffic to internet via O2 Homespot"

  lifecycle { create_before_destroy = true }
}

# =============================================================================
# MAC server and discovery hardening
# =============================================================================

resource "routeros_tool_mac_server" "this" {
  allowed_interface_list = routeros_interface_list.zones["lan"].name
}

resource "routeros_tool_mac_server_winbox" "this" {
  allowed_interface_list = routeros_interface_list.zones["lan"].name
}

resource "routeros_tool_bandwidth_server" "this" {
  enabled = false
}

resource "routeros_ip_neighbor_discovery_settings" "this" {
  discover_interface_list = routeros_interface_list.zones["lan"].name
}
