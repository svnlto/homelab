# Terraform native tests for MikroTik DHCP module (LAN VLAN)
# Run with: terragrunt test (or terraform test in the module directory)

mock_provider "routeros" {}

variables {
  mikrotik_api_url  = "https://192.168.0.3"
  mikrotik_username = "terraform"
  mikrotik_password = "test-password"
  vlan_name         = "lan"
  vlan_id           = 20
  vlan_interface    = "vlan-20-lan"
  subnet            = "192.168.0.0/24"
  gateway           = "192.168.0.1"
  dhcp_start        = "192.168.0.100"
  dhcp_end          = "192.168.0.149"
  dhcp_lease        = "24h"
  dns_servers       = ["192.168.0.53"]
}

# Test 1: Validate DHCP pool configuration
run "validate_dhcp_pool" {
  command = plan

  # Pool should exist
  assert {
    condition     = routeros_ip_pool.dhcp.name == "dhcp-pool-lan"
    error_message = "DHCP pool should be named 'dhcp-pool-lan'"
  }

  # Pool should have correct range
  assert {
    condition     = can(regex("192\\.168\\.0\\.100-192\\.168\\.0\\.149", routeros_ip_pool.dhcp.ranges[0]))
    error_message = "DHCP pool range should be 192.168.0.100-149"
  }
}

# Test 2: Validate DHCP server configuration
run "validate_dhcp_server" {
  command = plan

  # Server should exist with correct name
  assert {
    condition     = routeros_ip_dhcp_server.this.name == "dhcp-server-lan"
    error_message = "DHCP server should be named 'dhcp-server-lan'"
  }

  # Server should use the correct pool
  assert {
    condition     = routeros_ip_dhcp_server.this.address_pool == "dhcp-pool-lan"
    error_message = "DHCP server should use dhcp-pool-lan"
  }

  # Lease time should be 24 hours
  assert {
    condition     = routeros_ip_dhcp_server.this.lease_time == "24h"
    error_message = "LAN DHCP lease should be 24 hours"
  }
}

# Test 3: Validate DHCP network configuration
run "validate_dhcp_network" {
  command = plan

  # Network should match LAN subnet
  assert {
    condition     = routeros_ip_dhcp_server_network.this.address == "192.168.0.0/24"
    error_message = "DHCP network should be 192.168.0.0/24"
  }

  # Gateway should be Beryl AX
  assert {
    condition     = routeros_ip_dhcp_server_network.this.gateway == "192.168.0.1"
    error_message = "DHCP gateway should be 192.168.0.1 (Beryl AX)"
  }

  # DNS should be Pi-hole only
  assert {
    condition     = length(routeros_ip_dhcp_server_network.this.dns_server) == 1 && routeros_ip_dhcp_server_network.this.dns_server[0] == "192.168.0.53"
    error_message = "DNS should be Pi-hole only (192.168.0.53) - Pi-hole handles upstream fallbacks"
  }
}

# Test 4: Validate DHCP pool range
run "validate_pool_range" {
  command = plan

  # LAN pool should have correct range
  assert {
    condition     = routeros_ip_pool.dhcp.ranges[0] == "192.168.0.100-192.168.0.149"
    error_message = "LAN DHCP pool range should be 192.168.0.100-192.168.0.149"
  }
}

# Test 5: Validate outputs
run "validate_outputs" {
  command = plan

  # DHCP pool name should be output
  assert {
    condition     = output.dhcp_pool_name == "dhcp-pool-lan"
    error_message = "dhcp_pool_name output should match pool name"
  }

  # DHCP server name should be output
  assert {
    condition     = output.dhcp_server_name == "dhcp-server-lan"
    error_message = "dhcp_server_name output should match server name"
  }
}
