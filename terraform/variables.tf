variable "proxmox_api_url" {
  description = "Proxmox API URL"
  type        = string
  default     = "https://192.168.0.10:8006/api2/json"
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

variable "proxmox_node" {
  description = "Proxmox node name"
  type        = string
  default     = "pve"
}

variable "puid" {
  description = "User ID for Docker containers (file permissions)"
  type        = string
  default     = "1000"
}

variable "pgid" {
  description = "Group ID for Docker containers (file permissions)"
  type        = string
  default     = "1000"
}

# =============================================================================
# Talos Kubernetes Cluster Variables
# =============================================================================

variable "talos_version" {
  description = "Talos Linux version"
  type        = string
  default     = "v1.11.6"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "v1.32.3"
}

variable "cluster_name" {
  description = "Talos cluster name"
  type        = string
  default     = "homelab-k8s"
}

variable "cluster_endpoint" {
  description = "Kubernetes API endpoint (VIP)"
  type        = string
  default     = "https://10.0.1.10:6443"
}

variable "deploy_talos_bootstrap" {
  description = "Deploy Talos bootstrap components (Cilium, CSI, MetalLB)"
  type        = bool
  default     = false
}

variable "truenas_api_url" {
  description = "TrueNAS API URL"
  type        = string
  default     = "https://192.168.0.13"
}

variable "truenas_api_key" {
  description = "TrueNAS API key for democratic-csi"
  type        = string
  sensitive   = true
  default     = ""
}

variable "truenas_iscsi_portal" {
  description = "TrueNAS iSCSI portal (IP:port)"
  type        = string
  default     = "192.168.0.13:3260"
}
