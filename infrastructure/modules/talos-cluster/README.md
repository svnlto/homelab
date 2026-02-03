# Talos Cluster Module

Reusable Terraform module for deploying Talos Linux Kubernetes clusters on Proxmox with optional bootstrap components.

## Features

- **Automated Image Management**: Auto-generates Talos schematic with custom extensions
- **HA Control Plane**: Supports 1, 3, 5+ control plane nodes with VIP
- **GPU Passthrough**: Optional GPU passthrough for worker nodes
- **Bootstrap Components** (optional):
  - Cilium CNI
  - Democratic-CSI (NFS + iSCSI storage via TrueNAS)
  - MetalLB load balancer

## Usage

### Basic Cluster (Infrastructure Only)

```hcl
module "k8s_cluster" {
  source = "../modules/talos-cluster"

  # Cluster Identity
  cluster_name     = "homelab-k8s"
  cluster_endpoint = "https://10.0.1.10:6443"

  # Versions
  talos_version      = "v1.11.6"
  kubernetes_version = "v1.32.3"

  # Network
  network_bridge  = "vmbr1"
  network_gateway = "10.0.1.1"
  dns_servers     = ["192.168.0.53"]
  vip_ip          = "10.0.1.10"

  # Control Plane Nodes
  control_plane_nodes = {
    cp1 = {
      node_name    = "grogu"
      vm_id        = 110
      hostname     = "talos-cp1"
      ip_address   = "10.0.1.11/24"
      cpu_cores    = 2
      memory_mb    = 4096
      disk_size_gb = 32
    }
    cp2 = {
      node_name    = "din"
      vm_id        = 111
      hostname     = "talos-cp2"
      ip_address   = "10.0.1.12/24"
      cpu_cores    = 2
      memory_mb    = 4096
      disk_size_gb = 32
    }
    cp3 = {
      node_name    = "grogu"
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
      node_name       = "grogu"
      vm_id           = 120
      hostname        = "talos-worker1"
      ip_address      = "10.0.1.21/24"
      cpu_cores       = 8
      memory_mb       = 16384
      disk_size_gb    = 100
      gpu_passthrough = true
      gpu_mapping_id  = "intel-arc-a310"
    }
  }

  # Credentials
  kubeconfig_path   = "${path.root}/../../kubeconfig"
  talosconfig_path  = "${path.root}/../../talosconfig"
}
```

### Full Stack with Bootstrap

```hcl
module "k8s_cluster" {
  source = "../modules/talos-cluster"

  # ... basic configuration above ...

  # Enable Bootstrap
  deploy_bootstrap = true

  # TrueNAS Storage
  truenas_api_url     = "https://192.168.0.13"
  truenas_api_key     = var.truenas_api_key
  truenas_nfs_dataset = "pool/kubernetes"
  truenas_iscsi_portal = "192.168.0.13:3260"
  truenas_iscsi_dataset = "pool/kubernetes"

  # MetalLB
  metallb_ip_range = "10.0.1.100-10.0.1.120"
}

# Configure Kubernetes provider
provider "kubernetes" {
  host = module.k8s_cluster.cluster_endpoint

  client_certificate     = base64decode(yamldecode(module.k8s_cluster.kubeconfig_raw).users[0].user.client-certificate-data)
  client_key             = base64decode(yamldecode(module.k8s_cluster.kubeconfig_raw).users[0].user.client-key-data)
  cluster_ca_certificate = base64decode(yamldecode(module.k8s_cluster.kubeconfig_raw).clusters[0].cluster.certificate-authority-data)
}

provider "helm" {
  kubernetes {
    host = module.k8s_cluster.cluster_endpoint

    client_certificate     = base64decode(yamldecode(module.k8s_cluster.kubeconfig_raw).users[0].user.client-certificate-data)
    client_key             = base64decode(yamldecode(module.k8s_cluster.kubeconfig_raw).users[0].user.client-key-data)
    cluster_ca_certificate = base64decode(yamldecode(module.k8s_cluster.kubeconfig_raw).clusters[0].cluster.certificate-authority-data)
  }
}
```

### Multiple Clusters

```hcl
module "prod_cluster" {
  source = "../modules/talos-cluster"

  cluster_name     = "prod"
  cluster_endpoint = "https://10.0.1.10:6443"
  vip_ip          = "10.0.1.10"

  control_plane_nodes = { ... }
  worker_nodes        = { ... }

  kubeconfig_path   = "${path.root}/../../prod-kubeconfig"
  talosconfig_path  = "${path.root}/../../prod-talosconfig"
}

module "staging_cluster" {
  source = "../modules/talos-cluster"

  cluster_name     = "staging"
  cluster_endpoint = "https://10.0.2.10:6443"
  vip_ip          = "10.0.2.10"

  control_plane_nodes = { ... }
  worker_nodes        = { ... }

  kubeconfig_path   = "${path.root}/../../staging-kubeconfig"
  talosconfig_path  = "${path.root}/../../staging-talosconfig"
}
```

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | -------- |
| cluster_name | Name of the Talos Kubernetes cluster | string | - | yes |
| cluster_endpoint | Kubernetes API endpoint (VIP with port) | string | - | yes |
| vip_ip | Virtual IP for HA control plane | string | - | yes |
| control_plane_nodes | Map of control plane node configurations | map(object) | - | yes |
| worker_nodes | Map of worker node configurations | map(object) | {} | no |
| talos_version | Talos Linux version | string | "v1.11.6" | no |
| kubernetes_version | Kubernetes version | string | "v1.32.3" | no |
| deploy_bootstrap | Whether to deploy bootstrap components | bool | false | no |
| truenas_api_key | TrueNAS API key for democratic-csi | string | "" | no |
| metallb_ip_range | MetalLB IP address range | string | "" | no |

See `variables.tf` for full list.

## Outputs

| Name | Description |
| ---- | ----------- |
| cluster_name | Cluster name |
| cluster_endpoint | Kubernetes API endpoint |
| schematic_id | Talos Image Factory schematic ID |
| control_plane_nodes | Control plane node information |
| worker_nodes | Worker node information |
| kubeconfig_path | Path to kubeconfig file |
| talosconfig_path | Path to talosconfig file |
| kubeconfig_raw | Raw kubeconfig content (sensitive) |

## Bootstrap Components

When `deploy_bootstrap = true`:

1. **Cilium CNI**: Deployed automatically after cluster bootstrap
2. **Democratic-CSI**: Deployed if `truenas_api_key` is provided
   - NFS storage class: `truenas-nfs-rwx` (ReadWriteMany)
   - iSCSI storage class: `truenas-iscsi-rwo` (ReadWriteOnce, default)
3. **MetalLB**: Deployed if `metallb_ip_range` is provided

## Requirements

- Proxmox cluster with configured network bridges
- TrueNAS instance (if using storage)
- Terraform >= 1.5.0
- Providers:
  - bpg/proxmox >= 0.89.0
  - siderolabs/talos >= 0.7.0
  - hashicorp/kubernetes >= 2.30.0
  - hashicorp/helm >= 2.14.0

## Notes

- Control plane nodes must be odd number (1, 3, 5, etc.) for etcd quorum
- VIP must be on same subnet as cluster nodes
- GPU passthrough requires Proxmox resource mapping configured
- Bootstrap components require Kubernetes/Helm providers configured
