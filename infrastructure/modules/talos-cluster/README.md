# Talos Cluster Module

Reusable Terraform module for deploying Talos Linux Kubernetes clusters on Proxmox with optional bootstrap components.

## Features

- **Disk Image Deployment**: Uses pre-built Talos NoCloud disk images from Talos Image Factory
- **Static IP Configuration**: Proxmox initialization blocks for network setup
- **HA Control Plane**: Supports 1, 3, 5+ control plane nodes (VIP optional for multi-node)
- **GPU Passthrough**: Optional GPU passthrough for worker nodes
- **Bootstrap Components** (optional):
  - Cilium CNI (deployed via inline manifests during bootstrap)
  - Democratic-CSI (NFS + iSCSI storage via TrueNAS)
  - MetalLB load balancer (L2 mode)

## Usage

### Basic Cluster (Infrastructure Only)

```hcl
module "k8s_cluster" {
  source = "../modules/talos-cluster"

  # Cluster Identity
  cluster_name     = "homelab-k8s"
  cluster_endpoint = "https://10.0.1.10:6443"

  # Versions
  talos_version      = "v1.12.2"
  kubernetes_version = "v1.35.0"

  # Talos Image (from proxmox-image module)
  talos_image_id = "local:iso/talos-<schematic>-v1.12.2-nocloud.img"

  # Proxmox Storage
  proxmox_node_storage = "din"
  datastore_id         = "local-zfs"

  # Network
  network_bridge  = "vmbr0"
  network_gateway = "192.168.0.1"
  dns_servers     = ["192.168.0.53"]
  vip_ip          = "10.0.1.10"  # Optional, only for multi-node HA

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

  # Tags
  tags = ["production", "kubernetes"]
}

# Configs auto-generated at: ./configs/kubeconfig-homelab-k8s and ./configs/talosconfig-homelab-k8s
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
| cluster_endpoint | Kubernetes API endpoint with port (e.g., <https://IP:6443>) | string | - | yes |
| talos_image_id | Proxmox file ID for uploaded Talos disk image | string | - | yes |
| proxmox_node_storage | Proxmox node name for storage | string | - | yes |
| datastore_id | Proxmox datastore for VM disks | string | - | yes |
| control_plane_nodes | Map of control plane node configurations | map(object) | - | yes |
| worker_nodes | Map of worker node configurations | map(object) | {} | no |
| vip_ip | Virtual IP for HA control plane (optional for single-node) | string | - | yes |
| talos_version | Talos Linux version | string | "v1.12.2" | no |
| kubernetes_version | Kubernetes version | string | "v1.35.0" | no |
| deploy_bootstrap | Whether to deploy bootstrap components | bool | false | no |
| truenas_api_key | TrueNAS API key for democratic-csi | string | "" | no |
| metallb_ip_range | MetalLB IP address range (e.g., "10.0.1.100-10.0.1.120") | string | "" | no |

See `variables.tf` for full list.

## Outputs

| Name | Description |
| ---- | ----------- |
| cluster_name | Cluster name |
| cluster_endpoint | Kubernetes API endpoint |
| control_plane_nodes | Control plane node information |
| worker_nodes | Worker node information |
| kubeconfig_path | Path to kubeconfig file (auto-generated in configs/) |
| talosconfig_path | Path to talosconfig file (auto-generated in configs/) |
| kubeconfig_raw | Raw kubeconfig content (sensitive) |
| talosconfig_raw | Raw talosconfig content (sensitive) |
| bootstrap_deployed | Whether bootstrap components were deployed |

## Bootstrap Components

When `deploy_bootstrap = true`:

1. **Cilium CNI**: Deployed DURING bootstrap via inline manifests
   - KubeProxy replacement enabled
   - Hubble observability included
   - Connects to localhost:7445 (KubePrism)
2. **Democratic-CSI**: Deployed via Helm if `truenas_api_key` is provided
   - NFS storage classes: `truenas-nfs-bulk`, `truenas-nfs-fast`, `truenas-nfs-scratch`
   - iSCSI storage class: `truenas-iscsi-rwo` (ReadWriteOnce, default)
3. **MetalLB**: Deployed via Helm if `metallb_ip_range` is provided
   - L2 announcement mode for bare-metal LoadBalancer services

## Requirements

- **Proxmox**: VE 8.x with configured network bridges
- **SSH Access**: Root SSH access to Proxmox nodes (for disk image import)
  - Configure SSH keys or 1Password SSH agent
  - Provider needs explicit node address configuration
- **Talos Disk Image**: Pre-uploaded via `proxmox-image` module
- **TrueNAS**: Instance required if using Democratic-CSI storage
- **Terraform**: >= 1.5.0
- **Providers**:
  - bpg/proxmox >= 0.93.0
  - siderolabs/talos >= 0.10.1
  - hashicorp/kubernetes >= 3.0.1
  - hashicorp/helm >= 3.1.1
  - hashicorp/local >= 2.6.1

## Notes

- **Control Plane**: Use odd numbers (1, 3, 5, etc.) for etcd quorum in HA setups
- **Single-Node Clusters**: For dev/test, use 1 control plane and point `cluster_endpoint` to the node IP (no VIP needed)
- **VIP Configuration**: Only needed for multi-node HA, must be on same subnet as cluster nodes
- **GPU Passthrough**: Requires Proxmox resource mapping configured in datacenter settings
- **Bootstrap Components**: Require Kubernetes/Helm providers configured with cluster credentials
- **Configs Location**: kubeconfig and talosconfig auto-generated in `configs/` subdirectory
- **Network Config**: Proxmox initialization blocks set static IPs, Talos config overrides after bootstrap
- **Cilium Deployment**: Uses inline manifests (not Helm) to deploy during cluster bootstrap for immediate networking
