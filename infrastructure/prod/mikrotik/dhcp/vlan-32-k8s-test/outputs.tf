output "dhcp_pool_name" {
  value = routeros_ip_pool.dhcp.name
}

output "dhcp_server_name" {
  value = routeros_ip_dhcp_server.this.name
}
