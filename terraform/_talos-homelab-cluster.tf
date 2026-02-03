# ==============================================================================
# Homelab Talos Kubernetes Cluster
# ==============================================================================
# TODO: Uncomment when Talos config patch files are ready
# Commented out to allow terraform validate to pass

/*
module "homelab_k8s" {
  source = "./modules/talos-cluster"

  # Cluster Identity
  cluster_name     = var.cluster_name
  cluster_endpoint = var.cluster_endpoint

  # Versions
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version

  # Network Configuration (VLAN 30 - K8s Shared Services)
  network_bridge  = local.bridge_k8s_shared          # vmbr30
  network_gateway = local.network_k8s_shared.gateway # 10.0.1.1
  dns_servers     = local.dns_servers                # Pi-hole + Cloudflare
  vip_ip          = local.k8s_shared_vip             # 10.0.1.10

  # Proxmox Configuration
  proxmox_node_storage = local.proxmox_secondary
  datastore_id         = "local-zfs"
  iso_datastore_id     = "local"

  # Control Plane Nodes (HA with 3 nodes)
  control_plane_nodes = {
    cp1 = {
      node_name    = local.proxmox_secondary
      vm_id        = 110
      hostname     = "talos-cp1"
      ip_address   = "10.0.1.11/24"
      cpu_cores    = 2
      memory_mb    = 4096
      disk_size_gb = 32
    }
    cp2 = {
      node_name    = local.proxmox_primary
      vm_id        = 111
      hostname     = "talos-cp2"
      ip_address   = "10.0.1.12/24"
      cpu_cores    = 2
      memory_mb    = 4096
      disk_size_gb = 32
    }
    cp3 = {
      node_name    = local.proxmox_secondary
      vm_id        = 112
      hostname     = "talos-cp3"
      ip_address   = "10.0.1.13/24"
      cpu_cores    = 2
      memory_mb    = 4096
      disk_size_gb = 32
    }
  }

  # Worker Nodes
  worker_nodes = {
    worker1 = {
      node_name       = local.proxmox_secondary
      vm_id           = 120
      hostname        = "talos-worker1"
      ip_address      = "10.0.1.21/24"
      cpu_cores       = 8
      memory_mb       = 16384
      disk_size_gb    = 100
      gpu_passthrough = true
      gpu_mapping_id  = "intel-arc-a310"
    }
    worker2 = {
      node_name       = local.proxmox_primary
      vm_id           = 121
      hostname        = "talos-worker2"
      ip_address      = "10.0.1.22/24"
      cpu_cores       = 6
      memory_mb       = 12288
      disk_size_gb    = 100
      gpu_passthrough = false
    }
    worker3 = {
      node_name       = local.proxmox_primary
      vm_id           = 122
      hostname        = "talos-worker3"
      ip_address      = "10.0.1.23/24"
      cpu_cores       = 6
      memory_mb       = 12288
      disk_size_gb    = 100
      gpu_passthrough = false
    }
  }

  # Bootstrap Components (Cilium, CSI, MetalLB)
  deploy_bootstrap = var.deploy_talos_bootstrap

  # TrueNAS Storage Configuration
  truenas_api_url       = var.truenas_api_url
  truenas_api_key       = var.truenas_api_key
  truenas_nfs_dataset   = "pool/kubernetes"
  truenas_iscsi_portal  = var.truenas_iscsi_portal
  truenas_iscsi_dataset = "pool/kubernetes"

  # MetalLB Load Balancer
  metallb_ip_range = "10.0.1.100-10.0.1.120"
}
*/
