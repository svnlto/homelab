# Terraform native tests for MikroTik DHCP module (K8s Apps VLAN)
# Run with: terragrunt test (or terraform test in the module directory)

mock_provider "routeros" {}

variables {
  mikrotik_api_url  = "https://192.168.0.3"
  mikrotik_username = "terraform"
  mikrotik_password = "test-password"
  vlan_name         = "k8s-apps"
  vlan_id           = 31
  vlan_interface    = "vlan-31-k8s-apps"
  subnet            = "10.0.2.0/24"
  gateway           = "10.0.2.1"
  dhcp_start        = "10.0.2.100"
  dhcp_end          = "10.0.2.199"
  dhcp_lease        = "12h"
  dns_servers       = ["192.168.0.53"]
}

# Test 1: Validate DHCP pool configuration
run "validate_dhcp_pool" {
  command = plan

  # Pool should exist
  assert {
    condition     = routeros_ip_pool.dhcp.name == "dhcp-pool-k8s-apps"
    error_message = "DHCP pool should be named 'dhcp-pool-k8s-apps'"
  }

  # Pool should have correct range
  assert {
    condition     = can(regex("10\\.0\\.2\\.100-10\\.0\\.2\\.199", routeros_ip_pool.dhcp.ranges[0]))
    error_message = "DHCP pool range should be 10.0.2.100-199"
  }
}

# Test 2: Validate DHCP server configuration
run "validate_dhcp_server" {
  command = plan

  # Server should exist with correct name
  assert {
    condition     = routeros_ip_dhcp_server.this.name == "dhcp-server-k8s-apps"
    error_message = "DHCP server should be named 'dhcp-server-k8s-apps'"
  }

  # Server should use the correct pool
  assert {
    condition     = routeros_ip_dhcp_server.this.address_pool == "dhcp-pool-k8s-apps"
    error_message = "DHCP server should use dhcp-pool-k8s-apps"
  }

  # Lease time should be 12 hours
  assert {
    condition     = routeros_ip_dhcp_server.this.lease_time == "12h"
    error_message = "K8s apps DHCP lease should be 12 hours"
  }
}

# Test 3: Validate DHCP network configuration
run "validate_dhcp_network" {
  command = plan

  # Network should match K8s apps subnet
  assert {
    condition     = routeros_ip_dhcp_server_network.this.address == "10.0.2.0/24"
    error_message = "DHCP network should be 10.0.2.0/24"
  }

  # Gateway should be K8s apps gateway
  assert {
    condition     = routeros_ip_dhcp_server_network.this.gateway == "10.0.2.1"
    error_message = "DHCP gateway should be 10.0.2.1"
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

  # K8s apps pool should have correct range
  assert {
    condition     = routeros_ip_pool.dhcp.ranges[0] == "10.0.2.100-10.0.2.199"
    error_message = "K8s apps DHCP pool range should be 10.0.2.100-10.0.2.199"
  }
}

# Test 5: Validate outputs
run "validate_outputs" {
  command = plan

  # DHCP pool name should be output
  assert {
    condition     = output.dhcp_pool_name == "dhcp-pool-k8s-apps"
    error_message = "dhcp_pool_name output should match pool name"
  }

  # DHCP server name should be output
  assert {
    condition     = output.dhcp_server_name == "dhcp-server-k8s-apps"
    error_message = "dhcp_server_name output should match server name"
  }
}
