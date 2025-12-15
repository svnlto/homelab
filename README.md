# Homelab Infrastructure

Infrastructure as Code for a home lab built with Raspberry Pi and Proxmox VE.

## Overview

This repository contains configurations for:

- **Raspberry Pi**: Pi-hole DNS server (Packer + Ansible)
- **Proxmox VE**: VM template building and deployment (Packer + Terraform + Ansible)

## Quick Start

```bash
# Enter Nix development environment (loads all tools)
nix develop

# See all available commands
just

# Build Pi-hole image for Raspberry Pi
just packer-build-pihole

# Build Proxmox Ubuntu template
just packer-build-proxmox

# Deploy VMs on Proxmox
just tf-apply
```

## Project Structure

```text
homelab/
├── packer/                # Packer image builders
│   ├── ubuntu-template/   # Proxmox Ubuntu template
│   └── rpi-pihole.pkr.hcl # Raspberry Pi Pi-hole image
│
├── terraform/             # Terraform configurations
│   └── proxmox/           # Proxmox VM deployment
│
├── ansible/               # Ansible playbooks
│   └── playbooks/         # Base VM configuration
│
├── raspberry-pi/          # Raspberry Pi documentation
├── docs/                  # Additional documentation
├── Vagrantfile           # VM for ARM image building
├── justfile              # Command runner
└── flake.nix             # Nix development environment
```

## Components

### Raspberry Pi - Pi-hole DNS Server

- **Purpose**: Network-wide DNS filtering and ad-blocking
- **Build Time**: 30-60 minutes
- **Location**: `raspberry-pi/`
- **See**: [raspberry-pi/README.md](raspberry-pi/README.md)

**Build:**

```bash
just packer-build-pihole
```

### Proxmox VE - VM Infrastructure

- **Purpose**: Template-based VM deployment
- **Build Time**: 15-30 minutes (template), 2-3 minutes (clone)
- **Location**: `proxmox/`
- **See**: [proxmox/README.md](proxmox/README.md)

**Workflow:**

```bash
# 1. Build Ubuntu template (one time)
just packer-build-proxmox

# 2. Deploy VMs from template
just tf-apply
```

## Prerequisites

### Required Tools (via Nix)

```bash
nix develop  # Loads: packer, ansible, terraform, just
```

Or install manually:

- Packer
- Ansible
- Terraform
- Just (command runner)

### Hardware

- **Proxmox Server**: Running at 192.168.1.37
- **Raspberry Pi 4**: For Pi-hole (192.168.1.2)

## Common Commands

```bash
# Raspberry Pi
just packer-validate-pihole    # Validate Pi-hole config
just packer-build-pihole       # Build Pi-hole image
just ssh-pihole                # SSH to Pi-hole

# Proxmox
just packer-validate-proxmox   # Validate template config
just packer-build-proxmox      # Build Ubuntu template
just tf-plan                   # Preview VM changes
just tf-apply                  # Deploy VMs
just tf-destroy                # Destroy VMs

# Development
just vagrant-up                # Start build VM
just vagrant-ssh               # SSH to build VM
just clean                     # Clean build artifacts
```

## Documentation

- **Raspberry Pi Setup**: [raspberry-pi/README.md](raspberry-pi/README.md)
- **Packer Templates**: [packer/ubuntu-template/README.md](packer/ubuntu-template/README.md)
- **Terraform VMs**: [terraform/proxmox/README.md](terraform/proxmox/README.md)

## Network Architecture

```text
Internet
    ↓
Router/Gateway (192.168.1.1)
    ↓
    ├── Pi-hole DNS (192.168.1.2)
    │       ↓
    │   DNS Filtering
    │
    └── Proxmox VE (192.168.1.37)
            ↓
        VM Infrastructure
```

## Technologies

- **Packer**: Immutable infrastructure (image building)
- **Ansible**: Configuration management
- **Terraform**: VM provisioning and lifecycle
- **Cloud-Init**: VM initialization
- **Nix**: Reproducible development environment
- **Just**: Command runner

## License

MIT
