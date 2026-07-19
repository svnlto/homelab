# Homelab Infrastructure

Infrastructure as Code for a homelab running NixOS, Terragrunt, and Ansible.

## Stack

| Layer | Tool | What it manages |
| ----- | ---- | --------------- |
| **DNS** | NixOS + Pi-hole | Ad-blocking DNS on Raspberry Pi (Unbound recursive via Mullvad DoT) |
| **VMs** | Terragrunt | Proxmox VM orchestration (Talos cluster, TrueNAS) |
| **Storage** | Ansible | TrueNAS SCALE datasets, shares, snapshots |
| **Network** | Terragrunt | MikroTik VLANs, firewall, DHCP, DNS, QoS |
| **Backup** | Ansible | Restic to Backblaze B2 (offsite) |
| **K8s** | Terragrunt + ArgoCD | Talos cluster; media (Arr, Jellyfin), photos (Immich), music (Navidrome) via Helm/GitOps |

## Hardware

| Node | Role | Specs |
| ---- | ---- | ----- |
| **grogu** (P700) | Single-node Proxmox host | 28C/56T, Intel Arc A310, ~28TB ZFS, 10GbE |
| **Raspberry Pi 4B** | DNS (Pi-hole) | Dedicated, independent of Proxmox |
| **MikroTik CRS310** | Switching | L3 core + 10G aggregation |

**Design principle:** Raspberry Pi runs DNS independently of Proxmox so DNS stays operational during maintenance.

## Network

| Host | LAN (VLAN 20) | Storage (VLAN 10) |
| ---- | ------------- | ----------------- |
| MikroTik (nevarro) | 192.168.0.1 | -- |
| Pi-hole (RPi) | 192.168.0.53 | -- |
| grogu (P700) | 192.168.0.10 | 10.10.10.10 |
| TrueNAS Primary | 192.168.0.13 | 10.10.10.13 |

VLANs: 1 (management/AMT), 10 (storage/10GbE), 20 (LAN), 30-32 (K8s clusters).
All IPs and VLANs defined in `infrastructure/globals.hcl`.

## Project Structure

```text
infrastructure/              Terragrunt deployments
  globals.hcl                Single source of truth (IPs, VLANs, versions, VM IDs)
  root.hcl                   Remote state config (Backblaze B2 backend)
  modules/                   Reusable Terraform modules
    vm/                      Generic Proxmox VM (UEFI, cloud-init, PCI passthrough)
    truenas-vm/              TrueNAS VM with HBA passthrough + dual networking
    proxmox-image/           ISO/disk download + upload with checksum verification
    images/                  Bundles the TrueNAS/NixOS/Talos images for a host
    talos-cluster/           Talos Kubernetes cluster
    argocd/                  ArgoCD deployment
  prod/
    provider.hcl             Proxmox provider + generated credential variables
    images/                  Centralized image downloads (TrueNAS, NixOS, Talos)
    compute/                 k8s-shared (Talos cluster), argocd
    storage/                 truenas-primary (VMID 300)
    mikrotik/                base, dhcp, dns, firewall, qos
    dns/                     ClouDNS wildcard records
    tailscale/               Tailscale ACL policy
    cloud/                   Linode photo relay
nix/                         NixOS configurations
  rpi-pihole/                Pi-hole + Unbound DNS (aarch64)
  rpi-devbox/                Repurposed Pi dev/build box (aarch64)
  osxphotos-export/          macOS photo export image
  common/constants.nix       Shared config (versions, IPs)
charts/                      Helm charts (arr-stack, jellyfin, immich, navidrome, ...)
kubernetes/                  ArgoCD Application manifests + per-cluster values
ansible/                     Playbooks for TrueNAS, Proxmox, Restic backup
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

# Terragrunt — plan/apply all or a single module
just tg-plan
just tg-apply-module prod/compute/k8s-shared
```

## Secrets

All credentials managed via [1Password CLI](docs/1password-setup.md) with Touch ID.
Environment variables auto-loaded by direnv from `.envrc`.

## License

MIT
