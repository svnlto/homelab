# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Homelab infrastructure automation using NixOS, Terragrunt, and Ansible:

- **Raspberry Pi**: Immutable Pi-hole DNS server (NixOS, Mullvad DNS-over-TLS via Unbound)
- **Proxmox VE**: Terragrunt-based VM deployment with environment separation (prod/dev)
- **TrueNAS SCALE**: ZFS-based network storage (Terragrunt VMs + Ansible configuration)
- **MikroTik**: Router configuration via Terragrunt (VLANs, firewall, DHCP)
- **Kubernetes**: Talos K8s cluster on Proxmox with ArgoCD GitOps (arr-stack, Jellyfin, etc.)

**Critical Design Principle**: Raspberry Pi runs DNS (Pi-hole) independently of Proxmox
so DNS stays operational during Proxmox maintenance.

## Commands

All commands use `just` (task runner). Environment auto-loads via direnv + 1Password.

```bash
just --list                              # Show all commands
just lint                                # Pre-commit hooks (all files)
```

### NixOS

```bash
# Pi-hole (Raspberry Pi) - builds in Vagrant VM (macOS can't cross-compile aarch64)
just nixos-vm-up                         # Start build VM (one-time)
just nixos-build-pihole                  # Build SD image
just nixos-flash-pihole /dev/rdiskX      # Flash to SD card
just nixos-deploy-pihole                 # Deploy config via SSH (rsync + nixos-rebuild)
just nixos-flake-update-pihole           # Update flake lock in VM

# QDevice (Raspberry Pi) - corosync-qnetd for Proxmox quorum
just nixos-build-qdevice                 # Build SD image
just nixos-flash-qdevice /dev/rdiskX     # Flash to SD card
just nixos-deploy-qdevice               # Deploy config via SSH

# Arr Stack (legacy NixOS config, now runs on K8s)
just nixos-install-arr-stack <ip>        # Initial install via nixos-anywhere
just nixos-update-arr-stack              # Deploy config via SSH
```

### Terragrunt

```bash
just tg-plan                             # Plan all modules
just tg-apply                            # Apply all modules
just tg-validate                         # Validate all modules
just tg-plan-module prod/storage/truenas-primary   # Single module
just tg-apply-module prod/storage/truenas-primary
just tg-list                             # List all Terragrunt modules
just tg-graph                            # Show dependency graph
```

### Ansible

```bash
just ansible-ping                        # Test Proxmox connectivity
just ansible-configure-all               # Configure all Proxmox nodes
just ansible-configure din               # Configure specific node
just truenas-setup                       # Configure primary TrueNAS
just truenas-backup-setup                # Configure backup TrueNAS
just truenas-replication                 # Setup ZFS replication (din -> grogu)
just restic-setup                        # Configure B2 backups
```

## Architecture

### Infrastructure (Terragrunt)

```text
infrastructure/
├── globals.hcl              # Single source of truth (VLANs, IPs, versions, resource mappings)
├── root.hcl                 # S3-compatible backend config (Backblaze B2, Amsterdam)
├── modules/
│   ├── truenas-vm/          # TrueNAS VM with HBA passthrough
│   ├── proxmox-image/       # ISO download/upload to Proxmox
│   ├── talos-cluster/       # Talos Kubernetes cluster
│   └── argocd/              # Argo CD deployment
├── prod/
│   ├── provider.hcl         # Proxmox provider (credentials from 1Password)
│   ├── resource-pools/      # Proxmox pool management
│   ├── images/              # Centralized ISO downloads (TrueNAS, NixOS)
│   ├── compute/k8s-shared/  # Talos K8s cluster (VLAN 30)
│   ├── compute/jellyfin/    # Jellyfin VM with Arc A310 GPU passthrough
│   ├── compute/pbs/         # Proxmox Backup Server VM
│   ├── compute/argocd/      # ArgoCD on k8s-shared
│   ├── storage/
│   │   ├── truenas-primary/ # VMID 300 on din (5×8TB + 21×900GB)
│   │   └── truenas-backup/  # VMID 301 on grogu (8×3TB)
│   └── mikrotik/            # Router: base, dhcp, firewall, dns
└── dev/
    └── resource-pools/
```

**Terragrunt module pattern** — every deployment has:

- `terragrunt.hcl` — loads `globals.hcl`, includes `provider.hcl`, sets `inputs`
- `main.tf` — calls a module or defines resources
- `variables.tf` / `outputs.tf`

**Terragrunt CLI** (v1.0+ syntax):

- `terragrunt run --all <cmd>` (not the old `run-all`)
- `terragrunt dag graph` (not the old `graph-dependencies`)

### NixOS Configurations

```text
nix/
├── flake.nix                # Three configs: rpi-pihole, rpi-qdevice (aarch64), arr-stack (x86_64)
├── common/constants.nix     # Shared values (IPs, image versions)
├── rpi-pihole/              # Pi-hole: pihole.nix, configuration.nix, tailscale.nix
├── rpi-qdevice/             # QDevice: qdevice.nix, configuration.nix (corosync-qnetd)
└── arr-stack/               # Media stack: arr.nix, configuration.nix, disk-config.nix
```

- `constants.nix` is passed via `specialArgs` to all configs
- Pi-hole uses Docker containers (pihole + unbound) managed by NixOS
- Unbound forwards DNS-over-TLS to Mullvad (`194.242.2.2@853`)
- Arr stack uses disko for declarative disk partitioning, deployed via nixos-anywhere

### Kubernetes (ArgoCD GitOps)

```text
kubernetes/
├── argocd-apps/             # ArgoCD Application manifests (one per app)
└── apps/
    ├── arr-stack/            # Media automation (Sonarr, Radarr, Prowlarr, etc.)
    ├── jellyfin/             # Media server + Jellyseerr
    ├── infrastructure/       # democratic-csi StorageClasses
    ├── dumper/               # Photo dump CronJob
    └── navidrome/            # Music server
```

- Single Talos cluster (`k8s-shared`, VLAN 30) managed via Terragrunt
- ArgoCD watches `kubernetes/` directory for app-of-apps pattern
- Apps use Kustomize with base/overlays structure (overlays per cluster)
- Storage via democratic-csi (NFS + iSCSI from TrueNAS)

### TrueNAS Deployment (3-phase)

1. **Terragrunt**: Creates VMs with HBA passthrough (`just tg-apply-module prod/storage/truenas-primary`)
2. **Manual**: Create ZFS pools via `midclt call pool.create` (arensb.truenas can't create pools)
3. **Ansible**: Configure datasets, shares, snapshots, replication (`just truenas-setup`)

See `docs/truenas-ansible-setup.md` for complete design.

## Credentials

All secrets managed via **1Password CLI** with Touch ID, loaded by `.envrc`:

- `PROXMOX_TOKEN_ID` / `PROXMOX_TOKEN_SECRET` — Proxmox API
- `MIKROTIK_USERNAME` / `MIKROTIK_PASSWORD` — MikroTik router
- `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` — Backblaze B2 (S3-compatible, for Terragrunt state)

SSH uses 1Password SSH agent. See `docs/1password-setup.md` for setup.

## Network

| Host              | LAN (VLAN 20)  | Storage (VLAN 10) | WAN              |
| ----------------- | -------------- | ----------------- | ---------------- |
| MikroTik (nevarro)| 192.168.0.1    | —                 | 192.168.8.2      |
| Pi-hole (RPi)     | 192.168.0.53   | —                 | —                |
| QDevice (RPi)     | 192.168.0.54   | —                 | —                |
| grogu (r630)      | 192.168.0.10   | 10.10.10.10       | —                |
| din (r730xd)      | 192.168.0.11   | 10.10.10.11       | —                |
| TrueNAS Primary   | 192.168.0.13   | 10.10.10.13       | —                |
| TrueNAS Backup    | 192.168.0.14   | 10.10.10.14       | —                |
| O2 Homespot       | —              | —                 | 192.168.8.1 (GW) |

VLANs: 1 (management/iDRAC), 10 (storage/10GbE), 20 (LAN), 30-32 (K8s clusters).

All IPs and VLANs defined in `infrastructure/globals.hcl`. Proxmox host networking configured via Ansible, not Terragrunt.

See `docs/network-architecture.md` for full documentation.

## Tool Versions

Pinned via Nix flakes (`flake.nix`):

- Terraform 1.14.1 (from nixpkgs-terraform)
- Terragrunt (from nixpkgs)
- Ansible (from nixpkgs-unstable)
- Proxmox Provider 0.96.0 (bpg/proxmox)

## Pre-commit Hooks

Configured in `.pre-commit-config.yaml`:

- **General**: trailing-whitespace, end-of-file-fixer, check-yaml, yamlfmt, shellcheck, markdownlint
- **Terraform**: `terraform_fmt` for `infrastructure/**/*.tf`
- **Ansible**: ansible-lint for `ansible/`
- **Nix**: nixfmt, statix, deadnix (statix W20 "repeated_keys" suppressed in `statix.toml`)

## Formatting Rules

- When outputting shell commands that are long or have multiple arguments, always use
  backslash line continuations so they are easy to copy-paste:

  ```bash
  rsync -avP --partial \
    /source/path/ \
    user@host:/destination/path/
  ```

- Never output a shell command that wraps mid-argument without a backslash — it will
  break when pasted into a terminal.

## Common Issues

### VM stuck at SeaBIOS boot screen

Ensure `bios = "ovmf"`, `machine = "q35"`, and `efi_disk` block present in module.

### TrueNAS pools not visible after VM creation

Pools must be created manually via `midclt call pool.create` before running Ansible playbooks.

### HBA passthrough not applied

1. Verify resource mapping in `globals.hcl` matches Proxmox UI (Datacenter > Resource Mappings)
2. Check module has `enable_hostpci = true` and `hostpci_mapping` set
3. Additional HBAs beyond the first must be added manually in Proxmox UI
4. Module uses `lifecycle.ignore_changes = [hostpci]` to allow manual additions
