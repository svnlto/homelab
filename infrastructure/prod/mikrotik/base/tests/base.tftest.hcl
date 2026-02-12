# Terraform native tests for MikroTik base module
# Run with: terragrunt test (or terraform test in the module directory)

mock_provider "routeros" {}

variables {
  mikrotik_api_url  = "https://192.168.0.1"
  mikrotik_username = "terraform"
  mikrotik_password = "test-password"
  bridge_name       = "bridge-vlans"

  wan_interface = "ether1"
  wan_address   = "192.168.8.2/24"
  wan_gateway   = "192.168.8.1"

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

  access_ports = {
    pihole      = { interface = "ether2", pvid = 20, comment = "Pi-hole DNS" }
    beryl_ap    = { interface = "ether3", pvid = 20, comment = "Beryl AX WiFi AP" }
    din_idrac   = { interface = "ether4", pvid = 1, comment = "din iDRAC" }
    grogu_idrac = { interface = "ether5", pvid = 1, comment = "grogu iDRAC" }
    qdevice     = { interface = "ether6", pvid = 20, comment = "Proxmox QDevice" }
  }

  trunk_ports = {
    sfp_plus1 = { interface = "sfp-sfpplus1", comment = "grogu 10GbE" }
    sfp_plus2 = { interface = "sfp-sfpplus2", comment = "din 10GbE" }
  }

  allowed_management_subnets = "192.168.0.0/24,10.10.1.0/24"
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

  # Verify LAN gateway (MikroTik is now the LAN gateway at .1)
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

# Test 4: Validate WAN configuration
run "validate_wan_config" {
  command = plan

  # WAN IP should be configured on ether1
  assert {
    condition     = routeros_ip_address.wan.address == "192.168.8.2/24"
    error_message = "WAN address should be 192.168.8.2/24"
  }

  assert {
    condition     = routeros_ip_address.wan.interface == "ether1"
    error_message = "WAN interface should be ether1"
  }

  # Default route should point to O2 Homespot
  assert {
    condition     = routeros_ip_route.default.dst_address == "0.0.0.0/0"
    error_message = "Default route destination should be 0.0.0.0/0"
  }

  assert {
    condition     = routeros_ip_route.default.gateway == "192.168.8.1"
    error_message = "Default gateway should be 192.168.8.1 (O2 Homespot)"
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

# Test 6: Validate access and trunk ports
run "validate_ports" {
  command = plan

  # Should have 5 access ports (pihole, beryl_ap, din_idrac, grogu_idrac, qdevice)
  assert {
    condition     = length(routeros_interface_bridge_port.access_ports) == 5
    error_message = "Expected 5 access ports (pihole, beryl_ap, din_idrac, grogu_idrac, qdevice)"
  }

  # Should have 2 trunk ports (sfp+1, sfp+2)
  assert {
    condition     = length(routeros_interface_bridge_port.trunk_ports) == 2
    error_message = "Expected 2 trunk ports (sfp_plus1, sfp_plus2)"
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

# Test 8: Service hardening
run "validate_service_hardening" {
  command = plan

  # Insecure services should be disabled
  assert {
    condition     = routeros_ip_service.ftp.disabled == true
    error_message = "FTP should be disabled"
  }

  assert {
    condition     = routeros_ip_service.telnet.disabled == true
    error_message = "Telnet should be disabled"
  }

  assert {
    condition     = routeros_ip_service.www.disabled == true
    error_message = "HTTP should be disabled"
  }

  assert {
    condition     = routeros_ip_service.api.disabled == true
    error_message = "Unencrypted API should be disabled"
  }

  # Enabled services should be restricted to management subnets
  assert {
    condition     = routeros_ip_service.ssh.address == "192.168.0.0/24,10.10.1.0/24"
    error_message = "SSH should be restricted to LAN and management subnets"
  }

  assert {
    condition     = routeros_ip_service.winbox.address == "192.168.0.0/24,10.10.1.0/24"
    error_message = "WinBox should be restricted to LAN and management subnets"
  }

  assert {
    condition     = routeros_ip_service.www_ssl.address == "192.168.0.0/24,10.10.1.0/24"
    error_message = "HTTPS should be restricted to LAN and management subnets"
  }

  assert {
    condition     = routeros_ip_service.api_ssl.address == "192.168.0.0/24,10.10.1.0/24"
    error_message = "API-SSL should be restricted to LAN and management subnets"
  }
}

# Test 9: Validate jumbo frames on SFP+ trunk ports
run "validate_jumbo_frames" {
  command = plan

  assert {
    condition     = length(routeros_interface_ethernet.sfp_mtu) == 2
    error_message = "Both SFP+ trunk ports should have MTU configured"
  }
}

# Test 10: Output validation
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

  # WAN interface output
  assert {
    condition     = output.wan_interface == "ether1"
    error_message = "wan_interface output should be ether1"
  }
}
