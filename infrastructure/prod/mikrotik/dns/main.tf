resource "routeros_ip_dns" "pihole" {
  servers               = [var.pihole_ip]
  allow_remote_requests = false
  cache_size            = 2048
}
