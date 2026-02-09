# ==============================================================================
# Dev Test Cluster - Input Variables
# ==============================================================================

# Provider Variables (injected by provider.hcl)
variable "proxmox_api_url" {
  type = string
}

variable "proxmox_api_token_id" {
  type = string
}

variable "proxmox_api_token_secret" {
  type      = string
  sensitive = true
}

variable "onepassword_account" {
  type        = string
  description = "1Password account ID for desktop app integration"
}

# Cluster Variables
variable "cluster_name" {
  type = string
}

variable "cluster_endpoint" {
  type = string
}

variable "talos_version" {
  type = string
}

variable "kubernetes_version" {
  type = string
}

variable "network_bridge" {
  type = string
}

variable "network_gateway" {
  type = string
}

variable "dns_servers" {
  type = list(string)
}

variable "vip_ip" {
  type = string
}

variable "proxmox_node_storage" {
  type = string
}

variable "datastore_id" {
  type = string
}

variable "talos_image_id" {
  description = "Proxmox file ID for the Talos disk image"
  type        = string
}

variable "control_plane_nodes" {
  type = map(object({
    node_name    = string
    vm_id        = number
    hostname     = string
    ip_address   = string
    cpu_cores    = number
    memory_mb    = number
    disk_size_gb = number
  }))
}

variable "worker_nodes" {
  type = map(object({
    node_name       = string
    vm_id           = number
    hostname        = string
    ip_address      = string
    cpu_cores       = number
    memory_mb       = number
    disk_size_gb    = number
    gpu_passthrough = bool
  }))
}

variable "tags" {
  type = list(string)
}

variable "deploy_bootstrap" {
  type = bool
}
