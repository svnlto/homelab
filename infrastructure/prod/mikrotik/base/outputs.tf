output "bridge_name" {
  value       = routeros_interface_bridge.main.name
  description = "VLAN-aware bridge name"
}

output "vlan_interfaces" {
  value = {
    for k, v in routeros_interface_vlan.vlans : k => v.name
  }
  description = "VLAN interface names"
}

output "vlan_gateways" {
  value = {
    for k, v in var.vlans : k => v.gateway
  }
  description = "VLAN gateway IPs"
}

output "wan_interface" {
  value       = var.wan_interface
  description = "WAN interface name"
}
