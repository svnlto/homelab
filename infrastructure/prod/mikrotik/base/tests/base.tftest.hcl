# Terraform native tests for MikroTik base module
# Run with: terragrunt test (or terraform test in the module directory)

mock_provider "routeros" {}

variables {
  mikrotik_api_url  = "https://192.168.0.3"
  mikrotik_username = "terraform"
  mikrotik_password = "test-password"
  bridge_name       = "bridge-vlans"

  vlans = {
    management = {
      id          = 1
      name        = "management"
      subnet      = "10.10.1.0/24"
      gateway     = "10.10.1.1"
      description = "iDRAC, switch management"
    }
    storage = {
      id          = 10
      name        = "storage"
      subnet      = "10.10.10.0/24"
      gateway     = "10.10.10.1"
      description = "10GbE NFS/iSCSI, TrueNAS"
    }
    lan = {
      id          = 20
      name        = "lan"
      subnet      = "192.168.0.0/24"
      gateway     = "192.168.0.1"
      description = "VMs, clients, WiFi"
    }
    k8s_shared = {
      id          = 30
      name        = "k8s-shared"
      subnet      = "10.0.1.0/24"
      gateway     = "10.0.1.1"
      description = "K8s shared services"
    }
    k8s_apps = {
      id          = 31
      name        = "k8s-apps"
      subnet      = "10.0.2.0/24"
      gateway     = "10.0.2.1"
      description = "K8s production apps"
    }
    k8s_test = {
      id          = 32
      name        = "k8s-test"
      subnet      = "10.0.3.0/24"
      gateway     = "10.0.3.1"
      description = "K8s testing/staging"
    }
  }

  interfaces = {
    wan_to_beryl = "ether1"
    pihole       = "ether2"
    sfp_plus1    = "sfp-sfpplus1"
    sfp_plus2    = "sfp-sfpplus2"
  }
}

# Test 1: Validate all required VLANs are created
run "validate_vlan_creation" {
  command = plan

  # Verify all 6 VLANs are created
  assert {
    condition     = length(routeros_interface_vlan.vlans) == 6
    error_message = "Expected 6 VLANs (management, storage, lan, k8s_shared, k8s_apps, k8s_test)"
  }

  # Verify LAN VLAN has correct ID
  assert {
    condition     = routeros_interface_vlan.vlans["lan"].vlan_id == 20
    error_message = "LAN VLAN should have ID 20"
  }

  # Verify K8s shared VLAN has correct ID
  assert {
    condition     = routeros_interface_vlan.vlans["k8s_shared"].vlan_id == 30
    error_message = "K8s shared VLAN should have ID 30"
  }

  # Verify storage VLAN has correct ID
  assert {
    condition     = routeros_interface_vlan.vlans["storage"].vlan_id == 10
    error_message = "Storage VLAN should have ID 10"
  }
}

# Test 2: Validate gateway IPs are correctly assigned
run "validate_gateway_ips" {
  command = plan

  # Verify LAN gateway
  assert {
    condition     = can(regex("192\\.168\\.0\\.1/24", routeros_ip_address.vlan_gateways["lan"].address))
    error_message = "LAN gateway should be 192.168.0.1/24"
  }

  # Verify storage gateway
  assert {
    condition     = can(regex("10\\.10\\.10\\.1/24", routeros_ip_address.vlan_gateways["storage"].address))
    error_message = "Storage gateway should be 10.10.10.1/24"
  }

  # Verify K8s shared gateway
  assert {
    condition     = can(regex("10\\.0\\.1\\.1/24", routeros_ip_address.vlan_gateways["k8s_shared"].address))
    error_message = "K8s shared gateway should be 10.0.1.1/24"
  }
}

# Test 3: Validate bridge configuration
run "validate_bridge_config" {
  command = plan

  # Bridge should have VLAN filtering enabled
  assert {
    condition     = routeros_interface_bridge.main.vlan_filtering == true
    error_message = "Bridge must have VLAN filtering enabled"
  }

  # Bridge should have correct name
  assert {
    condition     = routeros_interface_bridge.main.name == "bridge-vlans"
    error_message = "Bridge name should be 'bridge-vlans'"
  }
}

# Test 4: Validate default route exists
run "validate_default_route" {
  command = plan

  # Default route should exist
  assert {
    condition     = routeros_ip_route.default.dst_address == "0.0.0.0/0"
    error_message = "Default route destination should be 0.0.0.0/0"
  }

  # Default route should point to Beryl AX
  assert {
    condition     = routeros_ip_route.default.gateway == "192.168.0.1"
    error_message = "Default gateway should be 192.168.0.1 (Beryl AX)"
  }
}

# Test 5: Validate VLAN bridge membership
run "validate_vlan_membership" {
  command = plan

  # All VLANs should have bridge membership configured
  assert {
    condition     = length(routeros_interface_bridge_vlan.vlan_membership) == 6
    error_message = "All 6 VLANs should have bridge membership configured"
  }

  # LAN VLAN membership should reference correct bridge
  assert {
    condition     = routeros_interface_bridge_vlan.vlan_membership["lan"].bridge == "bridge-vlans"
    error_message = "VLAN membership should reference bridge-vlans"
  }
}

# Test 6: Validate trunk ports configuration
run "validate_trunk_ports" {
  command = plan

  # Should have 4 trunk ports configured
  assert {
    condition     = length(routeros_interface_bridge_port.trunk_ports) == 4
    error_message = "Expected 4 trunk ports (ether1, pihole, sfp_plus1, sfp_plus2)"
  }

  # Trunk ports should be added to bridge
  assert {
    condition     = routeros_interface_bridge_port.trunk_ports["wan_to_beryl"].bridge == "bridge-vlans"
    error_message = "Trunk ports should be members of bridge-vlans"
  }
}

# Test 7: Validate routing settings
run "validate_routing_settings" {
  command = plan

  # RP filter should be set to loose
  assert {
    condition     = routeros_ip_settings.routing.rp_filter == "loose"
    error_message = "RP filter should be set to 'loose' for multi-homed networks"
  }
}

# Test 8: Output validation
run "validate_outputs" {
  command = plan

  # Bridge name output should exist
  assert {
    condition     = output.bridge_name == "bridge-vlans"
    error_message = "Bridge name output should be 'bridge-vlans'"
  }

  # VLAN interfaces output should contain all VLANs
  assert {
    condition     = length(output.vlan_interfaces) == 6
    error_message = "vlan_interfaces output should contain all 6 VLANs"
  }

  # VLAN gateways output should contain all gateways
  assert {
    condition     = length(output.vlan_gateways) == 6
    error_message = "vlan_gateways output should contain all 6 gateways"
  }
}
