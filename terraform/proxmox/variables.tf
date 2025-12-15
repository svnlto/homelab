variable "proxmox_api_url" {
  description = "Proxmox API URL"
  type        = string
  default     = "https://192.168.1.37:8006/api2/json"
}

variable "proxmox_tls_insecure" {
  description = "Skip TLS verification for Proxmox API"
  type        = bool
  default     = true
}

variable "proxmox_api_token_id" {
  description = "Proxmox API token ID (e.g., root@pam!terraform)"
  type        = string
  sensitive   = true
}

variable "proxmox_api_token_secret" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "SSH public key for cloud-init authentication"
  type        = string
  sensitive   = true
}

variable "openvpn_user" {
  description = "OpenVPN username for VPN connection"
  type        = string
  sensitive   = true
  default     = ""
}

variable "openvpn_password" {
  description = "OpenVPN password for VPN connection"
  type        = string
  sensitive   = true
  default     = ""
}

variable "soulseek_username" {
  description = "Soulseek username"
  type        = string
  sensitive   = true
  default     = ""
}

variable "soulseek_password" {
  description = "Soulseek password"
  type        = string
  sensitive   = true
  default     = ""
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
  default     = "admin"
}

variable "enable_observability" {
  description = "Enable observability integration with exportarr"
  type        = bool
  default     = false
}
