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

- **IP**: 192.168.1.2
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

**Current VMs**:

| VM | IP | Stack |
| -- | -- | ----- |
| arr-server | 192.168.1.50 | Sonarr, Radarr, Prowlarr, qBittorrent |
| observability-server | 192.168.1.51 | Grafana, Prometheus, Loki, Alloy |
| truenas | 192.168.1.76 | ZFS storage (NFS/SMB shares) |

### TrueNAS Storage

```bash
just truenas-deploy  # Create VM, manually install via console
# Then automate with Ansible:
ansible-playbook ansible/playbooks/truenas-setup.yml
```

- **Storage**: 3x 100GB disks (RAIDZ1) = ~200GB usable
- **Datasets**: media, kubernetes, backups, vms
- **Automation**: `arensb.truenas` collection + `midclt` WebSocket API

## Key Technologies

- **Packer**: Immutable infrastructure (image building)
- **Terraform**: VM lifecycle management
- **Ansible**: Configuration management and provisioning
- **Cloud-Init**: VM initialization and SSH key injection
- **Nix**: Reproducible development environment
- **Just**: Command runner (replaces Makefiles)

## Network Layout

```text
Router (192.168.1.1)
├── Pi-hole DNS (192.168.1.2)       # Raspberry Pi #2
├── Proxmox (192.168.1.37)          # Lenovo P520
│   ├── Template (VM 9000)
│   ├── arr-server (192.168.1.50)
│   ├── observability (192.168.1.51)
│   └── truenas (192.168.1.76)
└── Tailscale (192.168.1.100)       # Raspberry Pi #1
```

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
