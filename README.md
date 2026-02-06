# Homelab Infrastructure

Infrastructure as Code for homelab built with Raspberry Pi, Proxmox VE, and Kubernetes using NixOS, Terragrunt, and Ansible.

## Overview

- **Raspberry Pi**: Immutable NixOS Pi-hole DNS (declarative configuration)
- **Proxmox VE**: VM orchestration with Terragrunt (Talos Kubernetes, TrueNAS)
- **TrueNAS SCALE**: ZFS storage with 3-pool architecture (~54TB usable)
- **Kubernetes**: Talos cluster with ArgoCD hub-and-spoke GitOps
- **GitOps**: Kustomize-based application deployment via ArgoCD

**Critical Design**: Pi-hole runs on dedicated Raspberry Pi hardware (NOT Proxmox) to ensure DNS remains
operational during Proxmox maintenance.

## Quick Start

```bash
# Enter Nix environment (auto-loads with direnv)
nix develop

# Build Pi-hole NixOS image (15-20 min first build, 2-5 min incremental)
just nixos-build-pihole
just nixos-flash-pihole /dev/rdiskX

# Deploy infrastructure with Terragrunt
cd infrastructure/dev/compute/test-cluster
terragrunt apply  # Deploy Talos Kubernetes cluster

cd infrastructure/dev/compute/argocd
terragrunt apply  # Deploy ArgoCD GitOps

# View all available commands
just --list
```

## Architecture

```text
┌─────────────────────────────────────────────────┐
│ Infrastructure Stack                             │
├─────────────────────────────────────────────────┤
│ 1. Terragrunt + Terraform                       │
│    → VM orchestration (Proxmox provider)        │
│    → Environment separation (dev/prod)          │
│    → DRY configuration with globals             │
│                                                  │
│ 2. Talos Kubernetes                             │
│    → Immutable Kubernetes distro                │
│    → Cilium CNI for networking                  │
│    → Test cluster: 2 control + 1 worker         │
│                                                  │
│ 3. ArgoCD GitOps                                │
│    → Hub-and-spoke pattern                      │
│    → Kustomize for per-cluster customization    │
│    → Automatic sync from Git (main branch)      │
│                                                  │
│ 4. TrueNAS + Ansible                            │
│    → ZFS storage (NFS/iSCSI)                    │
│    → Democratic-CSI for dynamic PVCs            │
│    → Ansible manages datasets/shares/snapshots  │
└─────────────────────────────────────────────────┘
```

## Project Structure

```text
homelab/
├── infrastructure/
│   ├── globals.hcl            # Single source of truth (IPs, versions, VLANs)
│   ├── modules/               # Reusable Terraform modules
│   │   ├── talos-cluster/     # Talos Kubernetes cluster
│   │   ├── truenas-vm/        # TrueNAS VM with HBA passthrough
│   │   └── argocd/            # ArgoCD deployment
│   ├── dev/                   # Development environment
│   │   └── compute/
│   │       ├── test-cluster/  # Talos K8s test cluster
│   │       └── argocd/        # ArgoCD GitOps hub
│   └── prod/                  # Production environment
│       ├── storage/           # TrueNAS Primary/Backup VMs
│       └── mikrotik/          # Router configuration
│
├── kubernetes/
│   ├── argocd-apps/           # ArgoCD Application definitions
│   └── apps/                  # Kustomize manifests (base + overlays)
│
├── ansible/
│   ├── playbooks/             # TrueNAS, Proxmox configuration
│   ├── roles/                 # Reusable roles
│   └── vars/                  # Dataset definitions, shares
│
├── nix/                       # NixOS configurations
│   └── pihole/                # Pi-hole declarative config
│
├── docs/                      # Setup guides (TrueNAS, network, 1Password)
├── justfile                   # Command runner
├── flake.nix                  # Nix dev environment
└── CLAUDE.md                  # Project guidance for Claude Code
```

## Current Deployment Status

| Component | Status | Details |
| --------- | ------ | ------- |
| **Pi-hole DNS** | ✅ Running | 192.168.0.53 - NixOS on Raspberry Pi 4B |
| **Proxmox Cluster** | ✅ Running | grogu + din (2 nodes) |
| **TrueNAS Primary** | ✅ Running | 192.168.0.13 - 3 pools (54TB usable) |
| **Talos K8s Test** | ✅ Running | 192.168.0.161-162, 171 (3 nodes) |
| **ArgoCD Hub** | ✅ Running | Deployed on test cluster, managing apps |
| **Whoami Test App** | ✅ Synced | GitOps demo app (Kustomize + ArgoCD) |
| **TrueNAS Backup** | ⏳ Pending | Awaiting grogu online (MikroTik switch) |
| **Prod K8s Clusters** | 📋 Planned | Shared-services + apps clusters |

## Components

### Pi-hole DNS (Raspberry Pi 4B)

**NixOS Build** (macOS via Vagrant VM):

```bash
just nixos-vm-up              # Start Vagrant VM (one-time)
just nixos-build-pihole       # Build SD image (15-20 min)
just nixos-flash-pihole /dev/rdiskX
```

- **IP**: 192.168.0.53
- **OS**: NixOS (declarative, immutable)
- **Purpose**: Network-wide DNS filtering and ad-blocking
- **Rollback**: 30-second reboot to previous generation

### Kubernetes Cluster (Talos)

**Test Cluster** (dev/compute/test-cluster):

```bash
cd infrastructure/dev/compute/test-cluster
terragrunt apply  # Deploy 3-node cluster (2 control + 1 worker)
```

- **Control Plane**: 192.168.0.161-162 (2 nodes, HA etcd)
- **Worker**: 192.168.0.171 (1 node)
- **CNI**: Cilium
- **GitOps**: ArgoCD hub-and-spoke
- **Storage**: Democratic-CSI (TrueNAS NFS/iSCSI)

### ArgoCD GitOps

**Hub Deployment** (on test cluster):

```bash
cd infrastructure/dev/compute/argocd
terragrunt apply  # Deploy ArgoCD with root Application
```

- **UI**: <https://localhost:8080> (port-forward)
- **Pattern**: Hub-and-spoke (test cluster manages all clusters)
- **Repository**: <https://github.com/svnlto/homelab>
- **Manifests**: `kubernetes/argocd-apps/` (watched by root app)
- **Apps**: Kustomize base + per-cluster overlays

### TrueNAS Storage

**3-Pool ZFS Architecture**:

| Pool | Drives | Layout | Raw | Usable | Purpose |
| ---- | ------ | ------ | --- | ------ | ------- |
| **fast** | 24× 900GB SAS + SLOG | 3× 8-drive RAIDZ2 | ~20TB | ~16TB | K8s PVCs, VMs, databases |
| **bulk** | 6× 7.15TB SATA | 1× 6-drive RAIDZ2 | 42.9TB | 25.3TB | Media, photos, cold storage |
| **scratch** | 6× 2.73TB SATA | 1× 6-drive RAIDZ1 | 16.4TB | 12.9TB | Downloads, CI cache, ML staging |
| **Total** | | | **~79TB** | **~54TB** | |

- **Management IP**: 192.168.0.13 (VLAN 20)
- **Storage IP**: 10.10.10.13 (VLAN 10, 10GbE)
- **Deployment**: Terragrunt (VM shell) + Manual pool creation + Ansible (datasets/shares)
- **Provisioning**: Democratic-CSI for dynamic Kubernetes PVCs

## Key Technologies

- **NixOS**: Declarative, immutable OS (Pi-hole)
- **Terragrunt**: DRY infrastructure orchestration (wraps Terraform)
- **Terraform**: VM lifecycle management (Proxmox provider)
- **Talos**: Immutable Kubernetes distro (API-managed, no SSH)
- **ArgoCD**: GitOps continuous delivery for Kubernetes
- **Kustomize**: Template-free Kubernetes configuration
- **Ansible**: Configuration management (TrueNAS, Proxmox)
- **ZFS**: Enterprise filesystem (TrueNAS storage pools)
- **Nix**: Reproducible development environment
- **Just**: Command runner (replaces Makefiles)

## Network Layout

> **Detailed network documentation**: [docs/network-layout.md](docs/network-layout.md)

```text
Internet → Beryl AX Router (192.168.0.1)
              ↓
    ┌─────────┼─────────────────────┐
    │         │                     │
    ↓         ↓                     ↓
Pi-hole    Proxmox Cluster    MikroTik Switches
192.168.0.53  (grogu + din)    (L3 Core + 10G Agg)
              ↓
    ┌─────────┴─────────┐
    ↓                   ↓
grogu (R630)        din (R730xd)
192.168.0.10        192.168.0.11
10.10.10.10         10.10.10.11
    │                   │
    └─── 10GbE Fiber ───┘
         (Storage VLAN 10)
              ↓
         TrueNAS SCALE
         192.168.0.13 (mgmt)
         10.10.10.13 (storage)
```

**VLAN Architecture**:

- **VLAN 1 (Management)**: 10.10.1.0/24 - iDRAC, switch management
- **VLAN 10 (Storage)**: 10.10.10.0/24 - NFS/iSCSI, 10GbE high-bandwidth traffic
- **VLAN 20 (LAN)**: 192.168.0.0/24 - VMs, services, clients
- **VLAN 30 (K8s Shared Services)**: 10.0.1.0/24 - Infrastructure cluster (ArgoCD, monitoring)
- **VLAN 31 (K8s Apps)**: 10.0.2.0/24 - Production apps cluster
- **VLAN 32 (K8s Test)**: 10.0.3.0/24 - Testing/staging cluster (current test cluster)

**Hardware**:

- **grogu** (Dell R630): 36C/72T, Intel Arc A310 GPU, 10GbE, MD1200 (8× 3TB for backup pool)
- **din** (Dell R730xd): 24C/48T, 10GbE storage host
  - 6× 7.15TB SATA (bulk pool: 42.9TB raw / 25.3TB usable)
  - 6× 2.73TB SATA (scratch pool: 16.4TB raw / 12.9TB usable)
  - 24× 900GB SAS 10K + 2× 128GB SSD SLOG (fast pool: ~20TB raw / ~16TB usable)
  - Dell MD1220 disk shelf (24× 900GB SAS via LSI 9201-8e)
- **Switches**: MikroTik CRS310-8G+2S+IN (L3 Core) + CRS310-1G-5S-4S+IN (10G Agg)
- **Pi-hole**: Raspberry Pi 4B - Critical DNS infrastructure (independent of Proxmox)
- **Total Storage**: ~79TB raw / ~54TB usable across 3 ZFS pools

## Documentation

- **TrueNAS Pool Setup**: [docs/truenas-pool-setup.md](docs/truenas-pool-setup.md)
- **TrueNAS Ansible Setup**: [docs/truenas-ansible-setup.md](docs/truenas-ansible-setup.md)
- **Kubernetes GitOps**: [kubernetes/README.md](kubernetes/README.md)
- **ArgoCD Module**: [infrastructure/modules/argocd/README.md](infrastructure/modules/argocd/README.md)
- **NixOS Pi-hole**: [nix/README.md](nix/README.md)
- **Network Architecture**: [docs/network-architecture.md](docs/network-architecture.md)
- **1Password Setup**: [docs/1password-setup.md](docs/1password-setup.md)
- **Project Guide**: [CLAUDE.md](CLAUDE.md)

## Development

```bash
# Enter Nix shell (or use direnv)
nix develop

# View all commands
just --list

# NixOS Pi-hole
just nixos-vm-up              # Start Vagrant VM
just nixos-build-pihole       # Build SD image
just nixos-flash-pihole /dev/rdiskX

# Terragrunt (infrastructure)
cd infrastructure/dev/compute/test-cluster
terragrunt plan               # Preview changes
terragrunt apply              # Deploy cluster
terragrunt destroy            # Tear down

# ArgoCD access
kubectl --kubeconfig infrastructure/dev/compute/test-cluster/configs/kubeconfig-test \
  port-forward svc/argocd-server -n argocd 8080:443
# Then: https://localhost:8080 (admin / changeme-ArgoCD-2024)

# Ansible (TrueNAS)
just ansible-ping             # Test connectivity
ansible-playbook ansible/playbooks/truenas-setup.yml

# Pre-commit hooks
pre-commit run --all-files
```

## Authentication

- **1Password Integration**: All secrets managed via 1Password CLI
  - Proxmox API tokens (Touch ID authentication)
  - MikroTik router credentials
  - Backblaze B2 (remote state backend)
  - GitHub tokens (ArgoCD repository access)
- **SSH**: 1Password SSH agent with Touch ID
- **ArgoCD**: GitHub Personal Access Token (stored in 1Password)
- **Environment**: `.envrc` auto-loads via direnv (fetches from 1Password)

## License

MIT
