variable "tailscale_auth_key" {
  description = "Tailscale auth key for registering the relay node (tag:photo-relay)"
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "ED25519 SSH public key for instance access"
  type        = string
}
