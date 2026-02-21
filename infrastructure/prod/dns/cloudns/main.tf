terraform {
  required_version = "1.14.5"

  required_providers {
    cloudns = {
      source  = "ClouDNS/cloudns"
      version = "1.0.10"
    }
  }
}

provider "cloudns" {
  auth_id  = var.cloudns_auth_id
  password = var.cloudns_auth_password
}

resource "cloudns_dns_record" "cluster_wildcard" {
  for_each = var.cluster_records

  name  = each.value.subdomain
  zone  = var.zone_name
  type  = "A"
  value = each.value.tailscale_ip
  ttl   = 300
}

output "dns_records" {
  description = "Created DNS records per cluster"
  value = {
    for k, v in cloudns_dns_record.cluster_wildcard : k => {
      fqdn  = "${v.name}.${v.zone}"
      value = v.value
    }
  }
}
