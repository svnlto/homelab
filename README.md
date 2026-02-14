# Homelab Infrastructure

Infrastructure as Code for a homelab running NixOS, Terragrunt, and Ansible.

## Stack

| Layer | Tool | What it manages |
| ----- | ---- | --------------- |
| **DNS** | NixOS + Pi-hole | Ad-blocking DNS on Raspberry Pi (Unbound recursive via Mullvad DoT) |
| **Quorum** | NixOS | Corosync QDevice on Raspberry Pi for Proxmox cluster quorum |
| **Media** | NixOS + Docker | Arr stack (Sonarr, Radarr, Prowlarr, qBittorrent, SABnzbd) on Proxmox VM |
| **Jellyfin** | NixOS | Jellyfin media server with Intel Arc A310 GPU passthrough |
| **Dumper** | NixOS | Tailscale rsync automation (photo dump to TrueNAS) |
| **VMs** | Terragrunt | Proxmox VM orchestration with environment separation (prod/dev) |
| **Storage** | Ansible | TrueNAS SCALE datasets, shares, snapshots, replication |
| **Network** | Terragrunt | MikroTik VLANs, firewall, DHCP, DNS forwarding |
| **Backup** | Ansible | Restic to Backblaze B2, ZFS replication (din to grogu) |
| **K8s** | Terragrunt | Talos cluster with ArgoCD GitOps |

## Hardware

| Node | Role | Specs |
| ---- | ---- | ----- |
| **din** (R730xd) | Storage + compute | 24C/48T, ~54TB ZFS (3 pools), 10GbE |
| **grogu** (R630) | Compute + backup | 36C/72T, Intel Arc A310, 10GbE |
| **Raspberry Pi 4B** | DNS (Pi-hole) + QDevice | Dedicated, independent of Proxmox |
| **MikroTik CRS310** | Switching | L3 core + 10G aggregation |

**Design principle:** Raspberry Pi runs DNS independently of Proxmox so DNS stays operational during maintenance.

## Network

| Host | LAN (VLAN 20) | Storage (VLAN 10) |
| ---- | ------------- | ----------------- |
| MikroTik (nevarro) | 192.168.0.1 | -- |
| Pi-hole (RPi) | 192.168.0.53 | -- |
| QDevice (RPi) | 192.168.0.54 | -- |
| Arr Stack | 192.168.0.50 | 10.10.10.50 |
| Jellyfin | 192.168.0.51 | 10.10.10.51 |
| Dumper | 192.168.0.52 | 10.10.10.52 |
| grogu (R630) | 192.168.0.10 | 10.10.10.10 |
| din (R730xd) | 192.168.0.11 | 10.10.10.11 |
| TrueNAS Primary | 192.168.0.13 | 10.10.10.13 |
| TrueNAS Backup | 192.168.0.14 | 10.10.10.14 |

VLANs: 1 (management/iDRAC), 10 (storage/10GbE), 20 (LAN), 30-32 (K8s clusters).
All IPs and VLANs defined in `infrastructure/globals.hcl`.

## Project Structure

```text
infrastructure/              Terragrunt deployments
  globals.hcl                Single source of truth (IPs, VLANs, versions, VM IDs)
  root.hcl                   Remote state config (Backblaze B2 backend)
  modules/                   Reusable Terraform modules
    vm/                      Generic Proxmox VM (UEFI, cloud-init, PCI passthrough)
    truenas-vm/              TrueNAS VM with HBA passthrough + dual networking
    proxmox-image/           ISO download/upload with checksum verification
    talos-cluster/           Talos Kubernetes cluster
    argocd/                  ArgoCD deployment
  prod/
    provider.hcl             Proxmox provider + generated credential variables
    resource-pools/          Proxmox pool management
    images/                  Centralized ISO downloads (TrueNAS, NixOS)
    compute/                 arr-stack, jellyfin, dumper VMs
    storage/                 truenas-primary (din), truenas-backup (grogu)
    mikrotik/                base, dhcp, dns, firewall
  dev/
    resource-pools/
    images/
    compute/                 test-cluster, argocd
nix/                         NixOS configurations
  rpi-pihole/                Pi-hole + Unbound DNS (aarch64)
  rpi-qdevice/               Corosync QDevice (aarch64)
  arr-stack/                 Media automation stack (x86_64)
  jellyfin/                  Jellyfin media server (x86_64)
  dumper/                    Tailscale rsync automation (x86_64)
  common/constants.nix       Shared config (versions, IPs)
ansible/                     Playbooks for TrueNAS, Proxmox, Restic backup
kubernetes/                  ArgoCD apps + Kustomize manifests
docs/                        Setup guides (TrueNAS, networking, 1Password)
```

## Quick Start

```bash
# Enter dev environment (auto-loads with direnv)
nix develop

# View all commands
just --list

# Deploy Pi-hole changes via SSH
just nixos-deploy-pihole

# Deploy arr-stack changes
just nixos-update-arr-stack

# Terragrunt — plan/apply all or a single module
just tg-plan
just tg-apply-module prod/compute/arr-stack
```

## Secrets

All credentials managed via [1Password CLI](docs/1password-setup.md) with Touch ID.
Environment variables auto-loaded by direnv from `.envrc`.

## License

MIT
