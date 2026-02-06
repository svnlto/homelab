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

resource "routeros_firewall_filter" "accept_established" {
  chain            = "forward"
  action           = "accept"
  connection_state = "established,related"
  comment          = "Accept established/related connections"
  place_before     = 0
}

resource "routeros_firewall_filter" "drop_invalid" {
  chain            = "forward"
  action           = "drop"
  connection_state = "invalid"
  comment          = "Drop invalid connections"

  depends_on = [routeros_firewall_filter.accept_established]
}

resource "routeros_firewall_filter" "lan_to_any" {
  chain             = "forward"
  action            = "accept"
  in_interface_list = routeros_interface_list.zones["lan"].name
  comment           = "LAN can access everything"

  depends_on = [routeros_firewall_filter.drop_invalid]
}

resource "routeros_firewall_filter" "k8s_to_storage" {
  chain              = "forward"
  action             = "accept"
  in_interface_list  = routeros_interface_list.zones["k8s"].name
  out_interface_list = routeros_interface_list.zones["storage"].name
  comment            = "K8s clusters can access storage"

  depends_on = [routeros_firewall_filter.lan_to_any]
}

resource "routeros_firewall_filter" "k8s_isolation" {
  chain              = "forward"
  action             = "drop"
  in_interface_list  = routeros_interface_list.zones["k8s"].name
  out_interface_list = routeros_interface_list.zones["k8s"].name
  comment            = "Isolate K8s clusters from each other"

  depends_on = [routeros_firewall_filter.k8s_to_storage]
}

resource "routeros_firewall_filter" "default_drop" {
  chain   = "forward"
  action  = "drop"
  comment = "Default deny all other traffic"

  depends_on = [routeros_firewall_filter.k8s_isolation]
}

# Source NAT - Masquerade outbound traffic to internet
resource "routeros_ip_firewall_nat" "masquerade" {
  chain         = "srcnat"
  action        = "masquerade"
  out_interface = var.wan_interface
  comment       = "Masquerade outbound traffic to internet via Beryl AX"
}
