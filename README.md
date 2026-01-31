# Homelab Infrastructure

Infrastructure as Code for homelab built with Raspberry Pi and Proxmox VE using Packer, Terraform, and Ansible.

## Overview

- **Raspberry Pi**: Immutable Pi-hole DNS image (ARM builder on macOS)
- **Proxmox VE**: Template-based VM deployment with automated provisioning
- **TrueNAS**: ZFS storage VM with Ansible automation

**Critical Design**: Pi-hole runs on dedicated Raspberry Pi hardware (NOT Proxmox) to ensure DNS remains
operational during Proxmox maintenance.

## Quick Start

```bash
# Enter Nix environment (auto-loads with direnv)
nix develop

# Build Pi-hole image (30-60 min)
just packer-build-pihole

# Build Proxmox template (70-90 min on Apple Silicon)
just packer-build-proxmox

# Deploy VMs (2-3 min)
just tf-apply

# Deploy TrueNAS
just truenas-deploy
```

## Architecture

```text
┌─────────────────────────────────────────────────┐
│ Three-Phase Build System                        │
├─────────────────────────────────────────────────┤
│ 1. Packer Template (70-90 min)                  │
│    → Ubuntu 24.04 + cloud-init + SSH hardening  │
│    → Creates template VM 9000                   │
│                                                  │
│ 2. Terraform Clone (2-3 min)                    │
│    → Clone VMs from template                    │
│    → Inject SSH keys via cloud-init             │
│                                                  │
│ 3. Ansible Provision                            │
│    → Deploy application stacks                  │
│    → Configure services                         │
└─────────────────────────────────────────────────┘
```

## Project Structure

```text
homelab/
├── packer/
│   ├── arm-builder/           # Pi-hole ARM image (VMware Fusion VM)
│   ├── x86-builder/           # Bootable disk images (Vagrant VM)
│   ├── proxmox-node/          # Proxmox node image (cloud-init based)
│   └── proxmox-templates/     # Ubuntu template for VM cloning
│
├── terraform/
│   ├── modules/ubuntu-vm/     # Reusable VM module (40+ parameters)
│   └── proxmox/               # VM definitions (arr, observability, truenas)
│
├── ansible/
│   ├── playbooks/             # Stack deployments (arr, observability, etc.)
│   └── roles/                 # Reusable roles (pihole, proxmox_install, etc.)
│
├── docs/                      # Setup guides (TrueNAS, hardware planning)
├── justfile                   # Command runner
└── flake.nix                  # Nix dev environment
```

## Components

### Pi-hole DNS (Raspberry Pi)

**Image Build** (macOS):

```bash
just arm-vm-up           # Start VMware Fusion VM
just packer-build-pihole # Build ARM image (30-60 min)
just pihole-flash disk=/dev/rdisk4
```

- **IP**: 192.168.0.53
- **Purpose**: Network-wide DNS filtering and ad-blocking
- **Builder**: VMware Fusion VM (Docker Desktop can't mount loop devices)

### Proxmox VMs

**Template Build**:

```bash
just packer-build-proxmox  # 70-90 min on Apple Silicon (TCG emulation)
```

**VM Deployment**:

```bash
just tf-apply    # Clone and provision VMs
just tf-destroy  # Clean up
```

**Current VMs/Containers**:

| VM/Container | IP | Stack |
| ------------ | -- | ----- |
| arr-stack (LXC) | 192.168.0.200 | Sonarr, Radarr, Prowlarr, qBittorrent |
| monitoring-server (VM) | 192.168.0.201 | Grafana, Prometheus, Loki, Alloy |
| TrueNAS SCALE (VM) | 192.168.0.13 (mgmt), 10.10.10.13 (storage) | ZFS storage (NFS/iSCSI) |

### TrueNAS Storage

- **Management IP**: 192.168.0.13 (VLAN 20 LAN)
- **Storage IP**: 10.10.10.13 (VLAN 10 dedicated storage network)
- **Hardware**: Dell MD1220 disk shelf (24x 2.5" SFF) connected via SAS to din (R730xd)
- **Purpose**: Primary NFS/iSCSI storage for Proxmox VMs and containers

## Key Technologies

- **Packer**: Immutable infrastructure (image building)
- **Terraform**: VM lifecycle management
- **Ansible**: Configuration management and provisioning
- **Cloud-Init**: VM initialization and SSH key injection
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

**Hardware**:

- **grogu** (Dell R630): 36C/72T, Intel Arc A310 GPU, 10GbE storage
- **din** (Dell R730xd): 24C/48T, Dell MD1220 disk shelf (24x SFF), 10GbE storage
- **Switches**: MikroTik CRS310-8G+2S+IN (L3 Core) + CRS310-1G-5S-4S+IN (10G Agg)
- **Pi-hole**: Raspberry Pi 4B - Critical DNS infrastructure (independent of Proxmox)

## Documentation

- **Packer Templates**: [packer/proxmox-templates/README.md](packer/proxmox-templates/README.md)
- **Terraform VMs**: [terraform/proxmox/README.md](terraform/proxmox/README.md)
- **TrueNAS Setup**: [docs/truenas-setup.md](docs/truenas-setup.md)
- **Hardware Planning**: [docs/hardware-planning.md](docs/hardware-planning.md)
- **Project Guide**: [CLAUDE.md](CLAUDE.md)

## Development

```bash
# Enter Nix shell (or use direnv)
nix develop

# View all commands
just

# Packer
just packer-validate-proxmox
just packer-build-proxmox

# Terraform
just tf-plan
just tf-apply
just tf-destroy

# Ansible
just ansible-lint
just ansible-playbook stack-arr.yml

# Cleanup
just clean
```

## Authentication

- **Proxmox API**: Token-based (via `.env`)
- **SSH**: 1Password SSH agent with Touch ID
- **VM Access**: Cloud-init injects SSH keys on clone

## License

MIT
