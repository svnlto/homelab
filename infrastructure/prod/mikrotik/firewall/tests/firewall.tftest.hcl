# Terraform native tests for MikroTik firewall module
# Run with: terraform test in the module directory (after terragrunt init)
# Or run: terragrunt test

mock_provider "routeros" {}

variables {
  mikrotik_api_url  = "https://192.168.0.3"
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

# Test 3: Validate firewall filter rules order
run "validate_firewall_rules_order" {
  command = plan

  # Rule 1: Accept established connections (should be first)
  assert {
    condition     = routeros_firewall_filter.accept_established.action == "accept"
    error_message = "accept_established should have accept action"
  }

  # Rule 1: Should accept established/related
  assert {
    condition     = routeros_firewall_filter.accept_established.connection_state == "established,related"
    error_message = "First rule should accept established,related connections"
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

# Test 4: Validate LAN access policy
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

# Test 5: Validate K8s to storage access
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

# Test 6: Validate K8s cluster isolation
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

# Test 7: Validate default deny rule
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

# Test 8: Validate NAT masquerade
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

# Test 9: Security policy validation
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
}
