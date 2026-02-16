# ==============================================================================
# Talos Cluster Module - Input Variables
# ==============================================================================

# Cluster Identity
variable "cluster_name" {
  description = "Name of the Talos Kubernetes cluster"
  type        = string
}

variable "cluster_endpoint" {
  description = "Kubernetes API endpoint (VIP with port)"
  type        = string
  validation {
    condition     = can(regex("^https://", var.cluster_endpoint))
    error_message = "Cluster endpoint must be HTTPS URL (e.g., https://10.0.1.10:6443)"
  }
}

# Talos Configuration
variable "talos_version" {
  description = "Talos Linux version"
  type        = string
  default     = "v1.12.2"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "v1.35.0"
}

variable "talos_image_id" {
  description = "Proxmox file ID for the pre-uploaded Talos disk image"
  type        = string
}

# Network Configuration
variable "network_bridge" {
  description = "Proxmox bridge for cluster network (e.g., vmbr30 for K8s Shared Services)"
  type        = string
}

variable "network_gateway" {
  description = "Gateway IP for cluster network"
  type        = string
}

variable "dns_servers" {
  description = "DNS servers for cluster nodes"
  type        = list(string)
  default     = ["192.168.0.53"]
}

variable "vip_ip" {
  description = "Virtual IP for HA control plane (without CIDR)"
  type        = string
}

# Proxmox Configuration
variable "datastore_id" {
  description = "Proxmox datastore for VM disks"
  type        = string
  default     = "local-zfs"
}

# Control Plane Nodes
variable "control_plane_nodes" {
  description = "Map of control plane node configurations"
  type = map(object({
    node_name    = string
    vm_id        = number
    hostname     = string
    ip_address   = string # CIDR format (e.g., "10.0.1.11/24")
    cpu_cores    = number
    memory_mb    = number
    disk_size_gb = number
  }))

  validation {
    condition     = length(var.control_plane_nodes) >= 1 && length(var.control_plane_nodes) % 2 == 1
    error_message = "Control plane must have odd number of nodes (1, 3, 5, etc.) for etcd quorum"
  }
}

# Worker Nodes
variable "worker_nodes" {
  description = "Map of worker node configurations"
  type = map(object({
    node_name       = string
    vm_id           = number
    hostname        = string
    ip_address      = string # CIDR format
    cpu_cores       = number
    memory_mb       = number
    disk_size_gb    = number
    gpu_passthrough = optional(bool, false)
    gpu_mapping_id  = optional(string, "")
  }))

  default = {}
}


# Tags
variable "tags" {
  description = "Additional tags to apply to VMs"
  type        = list(string)
  default     = []
}

# Bootstrap Configuration
variable "deploy_bootstrap" {
  description = "Whether to deploy bootstrap components (CSI, MetalLB, etc.)"
  type        = bool
  default     = false
}

variable "truenas_api_url" {
  description = "TrueNAS API URL (e.g., https://192.168.0.13)"
  type        = string
  default     = ""
}

variable "truenas_api_key" {
  description = "TrueNAS API key for democratic-csi"
  type        = string
  sensitive   = true
  default     = ""
}


variable "truenas_nfs_dataset" {
  description = "TrueNAS ZFS dataset for NFS"
  type        = string
  default     = "pool/kubernetes"
}

variable "truenas_iscsi_portal" {
  description = "TrueNAS iSCSI portal (IP:port)"
  type        = string
  default     = ""
}

variable "truenas_iscsi_dataset" {
  description = "TrueNAS ZFS dataset for iSCSI"
  type        = string
  default     = "pool/kubernetes"
}

variable "metallb_ip_range" {
  description = "MetalLB IP address range (e.g., 10.0.1.100-10.0.1.120)"
  type        = string
  default     = ""
}

variable "traefik_enabled" {
  description = "Deploy Traefik ingress controller"
  type        = bool
  default     = false
}
