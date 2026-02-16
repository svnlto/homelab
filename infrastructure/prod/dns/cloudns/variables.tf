variable "cloudns_auth_id" {
  description = "ClouDNS auth-id"
  type        = number
  sensitive   = true
}

variable "cloudns_auth_password" {
  description = "ClouDNS API password"
  type        = string
  sensitive   = true
}

variable "zone_name" {
  description = "DNS zone name (e.g., svenlito.com)"
  type        = string
}

variable "cluster_records" {
  description = "Map of cluster wildcard DNS records to create"
  type = map(object({
    subdomain    = string
    tailscale_ip = string
  }))
}
