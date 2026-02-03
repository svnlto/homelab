output "firewall_zones" {
  value = {
    for k, v in routeros_interface_list.zones : k => v.name
  }
  description = "Configured firewall zones"
}
