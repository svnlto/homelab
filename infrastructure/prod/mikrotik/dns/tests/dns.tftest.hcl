# Terraform native tests for MikroTik DNS module
# Run with: terragrunt test (or terraform test in the module directory)

mock_provider "routeros" {}

variables {
  mikrotik_api_url  = "https://192.168.0.1"
  mikrotik_username = "terraform"
  mikrotik_password = "test-password"
  pihole_ip         = "192.168.0.53"
}

# Test 1: Validate DNS configuration
run "validate_dns_config" {
  command = plan

  # DNS server should be Pi-hole
  assert {
    condition     = contains(routeros_ip_dns.pihole.servers, "192.168.0.53")
    error_message = "DNS should forward to Pi-hole (192.168.0.53)"
  }

  # Remote requests should be disabled (clients use Pi-hole directly)
  assert {
    condition     = routeros_ip_dns.pihole.allow_remote_requests == false
    error_message = "Remote DNS requests should be disabled (clients use Pi-hole directly)"
  }

  # Cache should be enabled with reasonable size
  assert {
    condition     = routeros_ip_dns.pihole.cache_size == 2048
    error_message = "DNS cache should be 2048 KB"
  }
}

# Test 2: Validate DNS architecture
run "validate_dns_architecture" {
  command = plan

  # Router should not proxy DNS (design decision)
  assert {
    condition     = routeros_ip_dns.pihole.allow_remote_requests == false
    error_message = "DNS architecture: router uses Pi-hole, clients connect directly (no proxy)"
  }
}
