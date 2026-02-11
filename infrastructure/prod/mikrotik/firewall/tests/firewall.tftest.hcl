# Terraform native tests for MikroTik firewall module
# Run with: terraform test in the module directory (after terragrunt init)
# Or run: terragrunt test

mock_provider "routeros" {}

variables {
  mikrotik_api_url  = "https://192.168.0.1"
  mikrotik_username = "terraform"
  mikrotik_password = "test-password"
  wan_interface     = "ether1"

  vlan_interfaces = {
    management = "vlan-1-management"
    storage    = "vlan-10-storage"
    lan        = "vlan-20-lan"
    k8s_shared = "vlan-30-k8s-shared"
    k8s_apps   = "vlan-31-k8s-apps"
    k8s_test   = "vlan-32-k8s-test"
  }
}

# Test 1: Validate firewall zones are created
run "validate_firewall_zones" {
  command = plan

  # Should have 5 zones
  assert {
    condition     = length(routeros_interface_list.zones) == 5
    error_message = "Expected 5 firewall zones (wan, lan, management, storage, k8s)"
  }

  # WAN zone should exist
  assert {
    condition     = contains(keys(routeros_interface_list.zones), "wan")
    error_message = "WAN zone should exist"
  }

  # LAN zone should exist
  assert {
    condition     = contains(keys(routeros_interface_list.zones), "lan")
    error_message = "LAN zone should exist"
  }

  # K8s zone should exist
  assert {
    condition     = contains(keys(routeros_interface_list.zones), "k8s")
    error_message = "K8s zone should exist"
  }
}

# Test 2: Validate zone membership
run "validate_zone_membership" {
  command = plan

  # K8s zone should have 3 interfaces (shared, apps, test)
  assert {
    condition = length([
      for member in routeros_interface_list_member.zone_members :
      member if member.list == "k8s"
    ]) == 3
    error_message = "K8s zone should have 3 interfaces"
  }
}

# Test 3: Validate input chain rules (router protection)
run "validate_input_chain" {
  command = plan

  # Input chain: accept established
  assert {
    condition     = routeros_firewall_filter.input_accept_established.chain == "input"
    error_message = "input_accept_established should be in input chain"
  }

  assert {
    condition     = routeros_firewall_filter.input_accept_established.connection_state == "established,related"
    error_message = "Input chain should accept established/related connections"
  }

  # Input chain: drop invalid
  assert {
    condition     = routeros_firewall_filter.input_drop_invalid.action == "drop"
    error_message = "Input chain should drop invalid packets"
  }

  # Input chain: accept from LAN
  assert {
    condition     = routeros_firewall_filter.input_accept_lan.action == "accept"
    error_message = "Input chain should accept from LAN"
  }

  # Input chain: accept from K8s
  assert {
    condition     = routeros_firewall_filter.input_accept_k8s.action == "accept"
    error_message = "Input chain should accept from K8s (DHCP, DNS)"
  }

  # Input chain: accept ICMP
  assert {
    condition     = routeros_firewall_filter.input_accept_icmp.protocol == "icmp"
    error_message = "Input chain should accept ICMP"
  }

  # Input chain: drop WAN
  assert {
    condition     = routeros_firewall_filter.input_drop_wan.action == "drop"
    error_message = "Input chain should drop all other WAN input"
  }
}

# Test 4: Validate forward chain rules order
run "validate_firewall_rules_order" {
  command = plan

  # Rule 1: Accept established connections
  assert {
    condition     = routeros_firewall_filter.accept_established.action == "accept"
    error_message = "accept_established should have accept action"
  }

  assert {
    condition     = routeros_firewall_filter.accept_established.connection_state == "established,related"
    error_message = "First forward rule should accept established,related connections"
  }

  # Rule 2: Should drop invalid
  assert {
    condition     = routeros_firewall_filter.drop_invalid.action == "drop"
    error_message = "Invalid connections should be dropped"
  }

  assert {
    condition     = routeros_firewall_filter.drop_invalid.connection_state == "invalid"
    error_message = "Second rule should drop invalid connections"
  }
}

# Test 5: Validate LAN access policy
run "validate_lan_access" {
  command = plan

  # LAN should be able to access everything
  assert {
    condition     = routeros_firewall_filter.lan_to_any.action == "accept"
    error_message = "LAN should have accept action for all traffic"
  }

  assert {
    condition     = routeros_firewall_filter.lan_to_any.chain == "forward"
    error_message = "LAN rule should be in forward chain"
  }
}

# Test 6: Validate K8s to storage access
run "validate_k8s_storage_access" {
  command = plan

  # K8s clusters should be able to access storage
  assert {
    condition     = routeros_firewall_filter.k8s_to_storage.action == "accept"
    error_message = "K8s should have access to storage VLAN"
  }

  # Should have correct in/out interface lists
  assert {
    condition = (
      routeros_firewall_filter.k8s_to_storage.in_interface_list == "k8s" &&
      routeros_firewall_filter.k8s_to_storage.out_interface_list == "storage"
    )
    error_message = "K8s to storage rule should match in:k8s out:storage"
  }
}

# Test 7: Validate K8s to WAN access
run "validate_k8s_wan_access" {
  command = plan

  # K8s clusters should be able to access internet
  assert {
    condition     = routeros_firewall_filter.k8s_to_wan.action == "accept"
    error_message = "K8s should have access to internet (WAN)"
  }

  assert {
    condition = (
      routeros_firewall_filter.k8s_to_wan.in_interface_list == "k8s" &&
      routeros_firewall_filter.k8s_to_wan.out_interface_list == "wan"
    )
    error_message = "K8s to WAN rule should match in:k8s out:wan"
  }
}

# Test 8: Validate K8s cluster isolation
run "validate_k8s_isolation" {
  command = plan

  # K8s clusters should be isolated from each other
  assert {
    condition     = routeros_firewall_filter.k8s_isolation.action == "drop"
    error_message = "K8s clusters should be isolated (drop action)"
  }

  # Should block K8s to K8s traffic
  assert {
    condition = (
      routeros_firewall_filter.k8s_isolation.in_interface_list == "k8s" &&
      routeros_firewall_filter.k8s_isolation.out_interface_list == "k8s"
    )
    error_message = "K8s isolation should block k8s→k8s traffic"
  }
}

# Test 9: Validate management and storage WAN access
run "validate_other_wan_access" {
  command = plan

  # Management should access internet
  assert {
    condition = (
      routeros_firewall_filter.mgmt_to_wan.action == "accept" &&
      routeros_firewall_filter.mgmt_to_wan.in_interface_list == "management" &&
      routeros_firewall_filter.mgmt_to_wan.out_interface_list == "wan"
    )
    error_message = "Management should have internet access via WAN"
  }

  # Storage should access internet
  assert {
    condition = (
      routeros_firewall_filter.storage_to_wan.action == "accept" &&
      routeros_firewall_filter.storage_to_wan.in_interface_list == "storage" &&
      routeros_firewall_filter.storage_to_wan.out_interface_list == "wan"
    )
    error_message = "Storage should have internet access via WAN"
  }
}

# Test 10: Validate default deny rule
run "validate_default_deny" {
  command = plan

  # Should have default deny at the end
  assert {
    condition     = routeros_firewall_filter.default_drop.action == "drop"
    error_message = "Default rule should drop traffic"
  }

  assert {
    condition     = routeros_firewall_filter.default_drop.chain == "forward"
    error_message = "Default deny should be in forward chain"
  }
}

# Test 11: Validate NAT masquerade
run "validate_nat_masquerade" {
  command = plan

  # NAT rule should exist
  assert {
    condition     = routeros_ip_firewall_nat.masquerade.chain == "srcnat"
    error_message = "NAT should be in srcnat chain"
  }

  # Should use masquerade action
  assert {
    condition     = routeros_ip_firewall_nat.masquerade.action == "masquerade"
    error_message = "NAT should use masquerade action"
  }

  # Should apply to WAN interface
  assert {
    condition     = routeros_ip_firewall_nat.masquerade.out_interface == var.wan_interface
    error_message = "NAT should apply to WAN interface"
  }
}

# Test 12: Security policy validation
run "validate_security_policy" {
  command = plan

  # Verify stateful firewall (established connections accepted)
  assert {
    condition = (
      routeros_firewall_filter.accept_established.action == "accept" &&
      routeros_firewall_filter.accept_established.connection_state == "established,related"
    )
    error_message = "Firewall must be stateful (accept established/related connections)"
  }

  # Verify default deny exists
  assert {
    condition     = routeros_firewall_filter.default_drop.action == "drop"
    error_message = "Must have default deny policy"
  }

  # Verify invalid traffic is dropped
  assert {
    condition     = routeros_firewall_filter.drop_invalid.action == "drop"
    error_message = "Invalid traffic must be dropped"
  }

  # Verify WAN input is dropped
  assert {
    condition     = routeros_firewall_filter.input_drop_wan.action == "drop"
    error_message = "WAN input must be dropped (router protection)"
  }
}

# Test 13: Validate MAC server hardening
run "validate_mac_server_hardening" {
  command = plan

  # MAC server should be restricted to LAN
  assert {
    condition     = routeros_tool_mac_server.this.allowed_interface_list == "lan"
    error_message = "MAC server should be restricted to LAN interface list"
  }

  # MAC WinBox should be restricted to LAN
  assert {
    condition     = routeros_tool_mac_server_winbox.this.allowed_interface_list == "lan"
    error_message = "MAC WinBox should be restricted to LAN interface list"
  }
}

# Test 14: Validate bandwidth server and neighbor discovery
run "validate_discovery_hardening" {
  command = plan

  # Bandwidth server should be disabled
  assert {
    condition     = routeros_tool_bandwidth_server.this.enabled == false
    error_message = "Bandwidth server should be disabled"
  }

  # Neighbor discovery should be restricted to LAN
  assert {
    condition     = routeros_ip_neighbor_discovery_settings.this.discover_interface_list == "lan"
    error_message = "Neighbor discovery should be restricted to LAN"
  }
}
