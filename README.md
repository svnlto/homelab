# Homelab Infrastructure

Infrastructure as Code for a homelab running NixOS, Terragrunt, and Ansible.

## Stack

| Layer | Tool | What it manages |
| ----- | ---- | --------------- |
| **DNS** | NixOS + Pi-hole | Ad-blocking DNS on Raspberry Pi (Unbound recursive via Mullvad DoT) |
| **Media** | NixOS + Docker | Arr stack on Proxmox VM (Sonarr, Radarr, Jellyfin, etc.) |
| **VMs** | Terragrunt | Proxmox VM orchestration with environment separation |
| **Storage** | Ansible | TrueNAS SCALE datasets, shares, snapshots, replication |
| **Network** | Terragrunt | MikroTik VLANs, firewall, DHCP, DNS forwarding |
| **Backup** | Ansible | Restic to Backblaze B2, ZFS replication (din to grogu) |
| **K8s** | Terragrunt | Talos cluster with ArgoCD GitOps |

## Hardware

| Node | Role | Specs |
| ---- | ---- | ----- |
| **din** (R730xd) | Storage + compute | 24C/48T, ~54TB ZFS (3 pools), 10GbE |
| **grogu** (R630) | Compute + backup | 36C/72T, Intel Arc A310, 10GbE |
| **Raspberry Pi 4B** | DNS (Pi-hole) | Dedicated, independent of Proxmox |
| **MikroTik** | Switching | CRS310 L3 core + 10G aggregation |

## Project Structure

```text
infrastructure/          Terragrunt deployments (prod/dev environments)
  modules/               Reusable Terraform modules (truenas-vm, talos-cluster, etc.)
  globals.hcl            Single source of truth (IPs, VLANs, versions)
nix/                     NixOS configurations
  rpi-pihole/            Pi-hole + Unbound DNS
  arr-stack/             Media automation stack
  common/constants.nix   Shared config (versions, IPs)
ansible/                 Playbooks for TrueNAS, Proxmox, Restic backup
kubernetes/              ArgoCD apps + Kustomize manifests
docs/                    Setup guides (TrueNAS, networking, 1Password)
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

# Terragrunt
cd infrastructure/prod/storage/truenas-primary && terragrunt apply
```

## Secrets

All credentials managed via [1Password CLI](docs/1password-setup.md) with Touch ID.
Environment variables auto-loaded by direnv from `.envrc`.

## License

MIT
