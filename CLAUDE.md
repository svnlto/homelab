# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Homelab infrastructure automation using NixOS, Terragrunt, and Ansible:

- **Raspberry Pi**: Immutable Pi-hole DNS server (NixOS declarative config)
- **Proxmox VE**: Terragrunt-based VM deployment with environment separation
- **TrueNAS SCALE**: ZFS-based network storage (Terragrunt VMs + Ansible configuration)
- **MikroTik**: Router configuration via Terragrunt (VLANs, firewall, DHCP)

**Critical Design Principle**: Raspberry Pi runs critical network infrastructure (DNS) that must stay
operational during Proxmox maintenance. Pi-hole runs on the Pi, NOT on Proxmox.

## Architecture

### Infrastructure Stack (Terragrunt)

**Migration Status**: Migrated from Terraform to Terragrunt on 2026-02-03

- Old code archived in `archive/terraform-legacy-20260203/`
- New structure uses Terragrunt for DRY configuration and environment separation
- See `infrastructure/MIGRATION_COMPLETE.md` for details

**Directory Structure**:

```text
infrastructure/
├── globals.hcl                    # Single source of truth (VLANs, IPs, versions)
├── root.hcl                       # Backend + provider config (local state)
├── modules/                       # Reusable Terraform modules
│   ├── truenas-vm/               # DRY TrueNAS module (with HBA passthrough support)
│   └── talos-cluster/            # Talos Kubernetes cluster module
├── prod/                          # Production environment
│   ├── provider.hcl              # Proxmox provider config
│   ├── resource-pools/           # Proxmox pool management (prod-storage, prod-compute)
│   ├── iso-images/               # Centralized ISO downloads (TrueNAS)
│   ├── storage/
│   │   ├── truenas-primary/      # TrueNAS Primary (VMID 300, din)
│   │   └── truenas-backup/       # TrueNAS Backup (VMID 301, grogu)
│   └── mikrotik/                 # Router configuration (VLANs, firewall, DHCP, DNS)
│       ├── provider.hcl
│       ├── base/                 # Bridge, VLANs, IPs, routing
│       ├── dhcp/                 # Per-VLAN DHCP servers (4 VLANs)
│       ├── firewall/             # Zone-based firewall rules
│       └── dns/                  # DNS forwarding to Pi-hole
└── dev/                           # Development environment
    ├── provider.hcl
    └── resource-pools/
```

**Proxmox Nodes** (installed from official ISO):

- `grogu` (r630): 192.168.0.10 - Compute-focused node (currently offline, awaits MikroTik switch)
- `din` (r730xd): 192.168.0.11 - Storage + compute node (primary)
- Configured via Ansible (`ansible/playbooks/configure-existing-proxmox.yml`)

### Terragrunt Deployment Pattern

**Standard Structure** (every deployment):

```text
infrastructure/<env>/<category>/<module>/
├── terragrunt.hcl     # Loads globals.hcl, includes provider, sets inputs
├── main.tf            # Calls module or defines resources
├── variables.tf       # Variable declarations (including provider credentials)
├── outputs.tf         # Output definitions
```

**Key Files**:

- **globals.hcl**: Single source of truth (VLANs, IPs, versions, resource mappings)
- **root.hcl**: Backend configuration (currently local, B2 remote planned)
- **provider.hcl**: Provider configuration with credentials from .env

**Deployment Commands**:

```bash
# Apply single module
cd infrastructure/prod/storage/truenas-primary
terragrunt apply

# Apply all modules in directory
cd infrastructure/prod
terragrunt run-all apply

# Plan changes
terragrunt plan

# Destroy resources
terragrunt destroy
```

**Environment Variables** (auto-loaded via direnv from `.env`):

- `PROXMOX_TOKEN_ID` - Proxmox API token ID
- `PROXMOX_TOKEN_SECRET` - Proxmox API token secret
- `MIKROTIK_HOST` - MikroTik router IP
- `MIKROTIK_USERNAME` - MikroTik username
- `MIKROTIK_PASSWORD` - MikroTik password

### NixOS Pi-hole (Raspberry Pi)

**Build Environment**: Vagrant + VMware (macOS limitation)

Pi-hole runs on NixOS for true immutability and atomic updates. Build process:

1. **Start Vagrant VM** (one-time setup):

   ```bash
   just nixos-vm-up
   ```

2. **Build SD image** (15-20 min first build, 2-5 min incremental):

   ```bash
   just nixos-build-pihole
   ```

3. **Flash to SD card**:

   ```bash
   just nixos-flash-pihole /dev/rdiskX
   ```

4. **Boot and configure**:

   ```bash
   ssh svenlito@192.168.0.53
   docker exec pihole pihole setpassword 'your-password'
   ```

**Why NixOS over Packer**:

- True immutability (entire OS, not just containers)
- 30-second rollback (reboot to previous generation)
- Faster incremental builds (Nix cache)

**See**: nix/README.md for complete documentation (460 lines).

### TrueNAS Infrastructure

**Architecture**:

- Primary (VMID 300): VM on din (r730xd) with 5×8TB + 24×900GB storage
- Backup (VMID 301): VM on grogu (r630) with 8×3TB storage via MD1200
- Replication: ZFS send/recv over 10G DAC (VLAN 10)

**Deployment is 3-phase** (not fully automated):

#### Phase 1: Deploy VM Shells (Terragrunt)

```bash
cd infrastructure/prod/storage/truenas-primary
terragrunt apply  # Creates VMID 300

cd infrastructure/prod/storage/truenas-backup
terragrunt apply  # Creates VMID 301 (when grogu is online)
```

Terragrunt creates:

- Empty VMs with 32GB boot disk
- Network configuration (dual-homed for backup)
- **Primary**: H330 HBA passthrough via resource mapping (`truenas-h330`)
- **Backup**: Manual HBA passthrough needed (MD1200 controller)

**HBA Passthrough** is configured via Proxmox resource mappings in `globals.hcl`:

```hcl
resource_mappings = {
  truenas_h330 = "truenas-h330"  # Dell H330 Mini on din (5×8TB)
  truenas_lsi  = "truenas-lsi"   # LSI 9201-8e on din (MD1220, 24×900GB)
  md1200_hba   = "md1200-hba"    # MD1200 controller on grogu (8×3TB)
}
```

Primary VM uses `enable_hostpci = true` with `truenas-h330` mapping.
Additional HBAs must be added manually via Proxmox UI.

#### Phase 2: Pool Creation (Manual via midclt)

SSH into TrueNAS and create ZFS pools:

```bash
ssh admin@192.168.0.13  # Primary TrueNAS
midclt call pool.create '{...}'  # See docs/truenas-ansible-setup.md Part 5
```

**Why manual**: arensb.truenas collection doesn't support pool
creation.

#### Phase 3: Configure Datasets/Shares (Ansible)

```bash
# Create datasets, shares, users, snapshots, scrubs, SMART
ansible-playbook ansible/playbooks/truenas-setup.yml

# Setup ZFS replication (SSH keys + tasks)
ansible-playbook ansible/playbooks/truenas-replication.yml
```

**Ansible creates**:

- Datasets: bulk/media, fast/kubernetes, fast/databases
- NFS shares: for Kubernetes (democratic-csi), Jellyfin
- SMB shares: Time Machine backups
- Snapshot tasks: hourly (databases), daily (media)
- Replication: din → grogu over 10G

**See**: docs/truenas-ansible-setup.md for complete design (1200+ lines).

### Packer Template (Legacy - Not Currently Used)

**Note**: VM template building was part of old Terraform workflow. Current
Terragrunt setup recreates VMs from scratch without templates.

Packer template code archived in `packer/proxmox-templates/` for reference if needed in future.

## Essential Commands

### Development Environment

```bash
# Enter Nix shell (auto-loads with direnv)
nix develop

# All commands use direnv to load .env credentials
just --list
```

### Proxmox Node Configuration (after ISO install)

```bash
# Test connectivity to nodes
just ansible-ping

# Configure all Proxmox nodes (grogu + din)
just ansible-configure-all

# Configure specific node
just ansible-configure grogu
just ansible-configure din

# Note: Reboot required after configuration for PCIe passthrough
```

### Proxmox API Token Management

```bash
# Create Terraform API tokens (run after initial node setup)
just proxmox-create-api-tokens

# Tokens are displayed and saved to ansible/group_vars/all/vault.yml
# Add tokens to .env file, then reload direnv:
direnv allow

# View stored tokens (requires vault password)
just proxmox-view-tokens

# Rotate tokens (recommended every 90 days)
just proxmox-rotate-api-tokens
```

### Terragrunt Deployment

```bash
# Resource pools (run first)
cd infrastructure/prod/resource-pools
terragrunt apply

# ISO images (centralized downloads)
cd infrastructure/prod/iso-images
terragrunt apply

# TrueNAS VMs
cd infrastructure/prod/storage/truenas-primary
terragrunt apply

# Apply all prod infrastructure
cd infrastructure/prod
terragrunt run-all apply

# Destroy specific resource
cd infrastructure/prod/storage/truenas-primary
terragrunt destroy
```

### TrueNAS Configuration

```bash
# After manual HBA passthrough + pool creation:

# Configure datasets, shares, snapshots (dry run)
ansible-playbook ansible/playbooks/truenas-setup.yml --check

# Apply configuration
ansible-playbook ansible/playbooks/truenas-setup.yml

# Run specific tags only
ansible-playbook ansible/playbooks/truenas-setup.yml --tags=nfs,shares

# Setup replication din → grogu
ansible-playbook ansible/playbooks/truenas-replication.yml

# Verify configuration
ansible-playbook ansible/playbooks/truenas-setup.yml --tags=verify
```

### Raspberry Pi Workflow (NixOS)

```bash
# 1. Build NixOS SD image (15-20 min first, 2-5 min incremental)
just nixos-build-pihole

# 2. Flash to SD card
just nixos-flash-pihole /dev/rdiskX

# 3. Update flake to latest packages (optional)
just nixos-update-pihole
```

## Tool Versions

Pinned via Nix flakes for reproducibility:

- **Packer**: 1.14.3 (pinned nixpkgs commit)
- **Terraform**: 1.14.1 (from nixpkgs-terraform)
- **Terragrunt**: 0.71.6 (from nixpkgs)
- **Proxmox Provider**: 0.93.0 (bpg/proxmox)
- **Ansible**: Latest from nixpkgs-unstable

## Common Issues

### Terragrunt command not found in pre-commit

- **Cause**: Pre-commit hooks run outside direnv environment
- **Fix**: Terragrunt hooks disabled in `.pre-commit-config.yaml` - use direnv environment for manual runs
- **Verify**: `pre-commit run --all-files` should pass without terragrunt hooks

### VM stuck at SeaBIOS boot screen

- **Cause**: Missing UEFI configuration
- **Fix**: Ensure `bios = "ovmf"`, `machine = "q35"`, and `efi_disk` block present in module

### TrueNAS pools not visible after VM creation

- **Cause**: Pools don't exist yet (arensb.truenas can't create pools)
- **Fix**: Create pools manually via midclt before running ansible playbooks
- **Verify pools exist**: `midclt call pool.query` on TrueNAS

### Resource pool assignment not working

- **Cause**: Pool assignment happens during VM creation, not visible until refresh
- **Fix**: Run `terragrunt refresh` in resource-pools to see current members
- **Verify**: Check `pool_id` in VM state: `terragrunt state show 'module.truenas_primary.proxmox_virtual_environment_vm.truenas'`

### HBA passthrough not applied

- **Cause**: Resource mapping doesn't exist in Proxmox or module not configured
- **Fix**:
  1. Verify mapping in `globals.hcl` matches Proxmox UI (Datacenter → Resource Mappings)
  2. Check module has `enable_hostpci = true` and `hostpci_mapping` set
  3. Additional HBAs beyond first must be added manually in Proxmox UI
- **Lifecycle**: Module uses `lifecycle.ignore_changes = [hostpci]` to allow manual additions

## Network Architecture

See [docs/network-architecture.md](docs/network-architecture.md) for comprehensive network documentation.

**IP Assignments**:

- Router/Gateway (VLAN 20): 192.168.0.1
- Pi-hole DNS: 192.168.0.53 (Raspberry Pi)
- grogu (r630): 192.168.0.10 (VLAN 20 mgmt), 10.10.10.10 (VLAN 10 storage)
- din (r730xd): 192.168.0.11 (VLAN 20 mgmt), 10.10.10.11 (VLAN 10 storage)
- TrueNAS Primary: 192.168.0.13 (VLAN 20), 10.10.10.13 (VLAN 10)
- TrueNAS Backup: 192.168.0.14 (VLAN 20), 10.10.10.14 (VLAN 10)

**VLANs**:

- VLAN 1 (Management): 10.10.1.0/24 - iDRAC, switch management
- VLAN 10 (Storage): 10.10.10.0/24 - NFS/iSCSI, high-bandwidth storage traffic
- VLAN 20 (LAN): 192.168.0.0/24 - Infrastructure VMs, clients
- VLAN 30 (K8s Shared Services): 10.0.1.0/24 - Infrastructure cluster
- VLAN 31 (K8s Apps): 10.0.2.0/24 - Production apps cluster
- VLAN 32 (K8s Test): 10.0.3.0/24 - Testing/staging cluster

**Proxmox Host Networking** (configured via Ansible, NOT Terragrunt):

```bash
# One-time per-host configuration
just ansible-configure-all
```

Bridges: vmbr10 (Storage), vmbr20 (LAN), vmbr30/31/32 (K8s VLANs)

**Hardware**:

- r730xd: Dell PowerEdge R730xd (2U) - 24C/48T, Dell H330 Mini, LSI 9201-8e, 10GbE
- r630: Dell PowerEdge R630 (1U) - 36C/72T, Intel Arc A310 GPU, 10GbE
- DS2246: NetApp disk shelf with 24× 2.5" SFF bays
- **Total Cluster:** 60C/120T, 192-320GB RAM, Intel Arc A310 GPU

## Terragrunt Module Pattern

### Creating New Deployments

Each deployment follows the standard pattern:

```hcl
# infrastructure/prod/<category>/<module>/terragrunt.hcl
include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "provider" {
  path = find_in_parent_folders("provider.hcl")
}

# Dependencies (if needed)
dependencies {
  paths = ["../../resource-pools", "../../iso-images"]
}

# Load globals
locals {
  global_vars = read_terragrunt_config(find_in_parent_folders("globals.hcl"))
  # Extract needed values
  ips = local.global_vars.locals.infrastructure_ips
}

# Pass inputs to module
inputs = {
  node_name = "din"
  vm_id     = 300
  # ... other inputs from globals
}
```

### Using the truenas-vm Module

Example deployment configuration:

```hcl
# main.tf
module "truenas_primary" {
  source = "../../../modules/truenas-vm"

  # All inputs from terragrunt.hcl
  node_name           = var.node_name
  vm_id               = var.vm_id
  vm_name             = var.vm_name
  truenas_version     = var.truenas_version
  iso_id              = var.iso_id
  cpu_cores           = var.cpu_cores
  memory_mb           = var.memory_mb
  boot_disk_size_gb   = var.boot_disk_size_gb
  mac_address         = var.mac_address
  pool_id             = var.pool_id
  enable_hostpci      = var.enable_hostpci
  hostpci_mapping     = var.hostpci_mapping
}
```

**Module Benefits**:

- DRY configuration (no duplication between Primary/Backup)
- Consistent VM configuration
- Centralized HBA passthrough logic
- Environment separation (prod/dev)

## Authentication Flow

**SSH Agent Configuration** (1Password):

- Agent config: `~/.config/1Password/ssh/agent.toml`
- SSH key item name in 1Password: `"proxmox"` (in Personal vault)
- SSH config: `IdentityAgent "/Users/svenlito/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"`

**Proxmox API Tokens** (stored in `.env`, auto-loaded by direnv):

```bash
PROXMOX_TOKEN_ID="root@pam!terraform"
PROXMOX_TOKEN_SECRET="<uuid>"
```

## References

- Proxmox API: <https://192.168.0.11:8006/api2/json> (din - primary node)
- Terraform Proxmox Provider: <https://github.com/bpg/terraform-provider-proxmox>
- Terragrunt: <https://terragrunt.gruntwork.io/>
- Packer ARM Builder: <https://github.com/mkaczanowski/packer-builder-arm>
