---
name: infra
description: Infrastructure lifecycle management. Terragrunt modules, Ansible playbooks, NixOS configs, Proxmox VMs, MikroTik networking, and TrueNAS storage.
argument-hint: [command] [target]
disable-model-invocation: true
---

# Infrastructure Management

You are managing homelab infrastructure spanning Proxmox VE, MikroTik, TrueNAS, NixOS, and Terragrunt.

## Infrastructure Overview

### Proxmox Nodes

| Node  | Role             | LAN IP       | Storage IP  | iDRAC IP   |
|-------|------------------|--------------|-------------|------------|
| din   | Primary (R730xd) | 192.168.0.11 | 10.10.10.11 | 10.10.1.11 |
| grogu | Secondary (R630) | 192.168.0.10 | 10.10.10.10 | 10.10.1.10 |

### VM Inventory

| VMID    | Name            | Node      | Purpose                        |
|---------|-----------------|-----------|--------------------------------|
| 200     | arr-stack       | din       | NixOS media automation         |
| 210     | jellyfin        | grogu     | NixOS Jellyfin + Arc A310 GPU  |
| 220     | pbs             | grogu     | Proxmox Backup Server          |
| 300     | truenas-primary | din       | TrueNAS SCALE (H330+LSI HBA)   |
| 301     | truenas-backup  | grogu     | TrueNAS SCALE (H241 HBA)       |
| 400-402 | shared-cp*      | din/grogu | Talos K8s shared control plane |
| 410-411 | shared-worker*  | din/grogu | Talos K8s shared workers       |
| 500-502 | apps-cp*        | grogu     | Talos K8s apps control plane   |
| 510-511 | apps-worker*    | grogu     | Talos K8s apps workers         |

### Network (VLANs)

| VLAN | Name       | Subnet         | Bridge | Purpose            |
|------|------------|----------------|--------|--------------------|
| 1    | management | 10.10.1.0/24   | —      | iDRAC, switches    |
| 10   | storage    | 10.10.10.0/24  | vmbr10 | 10GbE NFS/iSCSI    |
| 20   | lan        | 192.168.0.0/24 | vmbr20 | VMs, clients, WiFi |
| 30   | k8s-shared | 10.0.1.0/24    | vmbr30 | K8s shared cluster |
| 31   | k8s-apps   | 10.0.2.0/24    | vmbr31 | K8s apps cluster   |
| 32   | k8s-test   | 10.0.3.0/24    | vmbr32 | K8s test cluster   |

## Commands Reference

When the user invokes `/infra`, parse `$ARGUMENTS` to determine the action.

### Terragrunt

- `/infra plan [module]` — Plan a Terragrunt module or all modules

  ```bash
  # Single module
  just tg-plan-module <module>

  # All modules
  just tg-plan
  ```

  Module paths are relative to `infrastructure/prod/` (e.g., `storage/truenas-primary`, `compute/k8s-shared`, `mikrotik/base`).

- `/infra apply [module]` — Apply a Terragrunt module
  **ALWAYS ask for explicit confirmation before applying.**

  ```bash
  just tg-apply-module <module>
  ```

- `/infra validate [module]` — Validate Terragrunt configuration

  ```bash
  just tg-validate
  ```

- `/infra list` — List all Terragrunt modules

  ```bash
  just tg-list
  ```

- `/infra graph` — Show Terragrunt dependency graph

  ```bash
  just tg-graph
  ```

- `/infra show <module>` — Read and summarize a module's configuration
  Read these files:
  - `infrastructure/prod/<module>/terragrunt.hcl`
  - `infrastructure/prod/<module>/main.tf`
  - `infrastructure/prod/<module>/variables.tf` (if exists)
  - The underlying module in `infrastructure/modules/` (if referenced)

### Module Inventory

```text
prod/
  resource-pools/              # Proxmox resource pool management
  images/                      # ISO/image downloads (TrueNAS, NixOS, Talos, PBS)
  compute/
    arr-stack/                 # NixOS arr media stack VM
    jellyfin/                  # NixOS Jellyfin + GPU passthrough VM
    pbs/                       # Proxmox Backup Server VM
    k8s-shared/                # Talos shared cluster (use /talos instead)
    k8s-apps/                  # Talos apps cluster (use /talos instead)
    argocd/                    # ArgoCD on k8s-shared (Helm)
  storage/
    truenas-primary/           # TrueNAS primary VM (din, HBA passthrough)
    truenas-backup/            # TrueNAS backup VM (grogu, HBA passthrough)
  mikrotik/
    base/                      # Bridge, VLANs, ports, WAN, jumbo frames
    firewall/                  # Firewall rules (depends on base)
    dns/                       # DNS forwarding to Pi-hole
    qos/                       # QoS shaping (depends on base)
    dhcp/
      vlan-20-lan/             # DHCP for LAN
      vlan-30-k8s-shared/      # DHCP for K8s shared
      vlan-31-k8s-apps/        # DHCP for K8s apps
      vlan-32-k8s-test/        # DHCP for K8s test
  dns/
    cloudns/                   # Wildcard DNS records for clusters
  tailscale/
    acl/                       # Tailscale ACL policy
dev/
  resource-pools/              # Dev Proxmox pools
  images/                      # Dev Talos images
```

### Ansible

- `/infra ansible <target>` — Run Ansible against a target

  ```bash
  # Proxmox nodes
  just ansible-ping                              # Test connectivity
  just ansible-configure-all                     # Configure all nodes
  just ansible-configure <host>                  # Configure specific node (din/grogu)

  # Proxmox networking
  just proxmox-configure-networking              # Configure VLAN bridges
  just proxmox-configure-networking-check        # Dry-run

  # Proxmox API tokens
  just proxmox-create-api-tokens
  just proxmox-rotate-api-tokens

  # TrueNAS
  just truenas-ping                              # Test connectivity
  just truenas-setup                             # Configure primary TrueNAS
  just truenas-backup-setup                      # Configure backup TrueNAS
  just truenas-replication                       # ZFS replication din -> grogu

  # Proxmox Backup Server
  just pbs-setup                                 # Post-install PBS config

  # Backups
  just restic-setup                              # Configure B2 cloud backups
  ```

- `/infra ansible-check` — Run Ansible lint

  ```bash
  just ansible-lint
  ```

### NixOS

- `/infra nixos <target>` — NixOS operations

  ```bash
  # Pi-hole (Raspberry Pi, aarch64)
  just nixos-vm-up                               # Start build VM (one-time)
  just nixos-build-pihole                        # Build SD image
  just nixos-flash-pihole /dev/rdiskX            # Flash to SD card
  just nixos-deploy-pihole                       # Deploy via SSH

  # QDevice (Raspberry Pi, corosync-qnetd)
  just nixos-build-qdevice                       # Build SD image
  just nixos-flash-qdevice /dev/rdiskX           # Flash to SD card
  just nixos-deploy-qdevice                      # Deploy via SSH

  # Arr Stack (Proxmox VM at 192.168.0.50)
  just nixos-install-arr-stack <ip>              # Initial install (nixos-anywhere)
  just nixos-update-arr-stack                    # Deploy via SSH

  # Jellyfin (Proxmox VM at 192.168.0.51)
  just nixos-install-jellyfin <ip>               # Initial install
  just nixos-update-jellyfin                     # Deploy via SSH
  ```

- `/infra nixos-show <config>` — Show a NixOS configuration
  Read files from `nix/<config>/` (e.g., `rpi-pihole`, `rpi-qdevice`, `arr-stack`).

### Proxmox

- `/infra proxmox status` — Show Proxmox cluster status
  Use the Proxmox MCP tools:
  - `proxmox_get_cluster_status` for cluster overview
  - `proxmox_get_nodes` for node list
  - `proxmox_get_vms` for all VMs

- `/infra proxmox node <name>` — Show detailed node status
  Use `proxmox_get_node_status` with node name (din or grogu).

- `/infra proxmox vm <vmid>` — Show VM status
  Use `proxmox_get_vm_status`. Determine node from the VM inventory above.

- `/infra proxmox storage` — Show storage pools
  Use `proxmox_get_storage`.

### MikroTik

- `/infra mikrotik show` — Show MikroTik router configuration
  Read and summarize modules under `infrastructure/prod/mikrotik/`.

- `/infra mikrotik plan` — Plan MikroTik changes

  ```bash
  just tg-plan-module prod/mikrotik/base
  just tg-plan-module prod/mikrotik/firewall
  just tg-plan-module prod/mikrotik/dns
  just tg-plan-module prod/mikrotik/qos
  ```

### TrueNAS

- `/infra truenas status` — Check TrueNAS connectivity and VM status

  ```bash
  just truenas-ping
  ```

  Also use `proxmox_get_vm_status` for VMIDs 300 (primary) and 301 (backup).

- `/infra truenas setup` — Run TrueNAS configuration
  **Ask for confirmation.**

  ```bash
  just truenas-setup                             # Primary
  just truenas-backup-setup                      # Backup
  ```

### Globals

- `/infra globals` — Show key values from globals.hcl
  Read and summarize `infrastructure/globals.hcl` (IPs, VLANs, versions, cluster config).

- `/infra globals edit` — Edit globals.hcl
  Open `infrastructure/globals.hcl` for editing.

### Linting & Validation

- `/infra lint` — Run all pre-commit hooks

  ```bash
  just lint
  ```

- `/infra fmt` — Format Terraform files

  ```bash
  just tg-fmt
  ```

## Argument Parsing Rules

1. If no arguments: show help summary of available commands
2. Module paths are relative to `infrastructure/prod/` unless prefixed with `dev/`
3. For Ansible targets, match against the `just` commands listed above

## Safety Rules

- **NEVER run `terragrunt apply`, `terragrunt destroy`, or `terraform destroy` without explicit user confirmation**
- **NEVER run Ansible playbooks that modify state without confirmation** (pings and checks are safe)
- **NEVER flash SD cards or run nixos-anywhere without confirmation**
- **NEVER modify MikroTik configuration without confirmation** (can cause network outages)
- For destructive Proxmox operations (delete VM, stop VM), always confirm first
- DNS (Pi-hole) runs independently of Proxmox — never take actions that assume otherwise

## Key File Paths

- **Globals**: `infrastructure/globals.hcl`
- **Root config**: `infrastructure/root.hcl`
- **Provider config**: `infrastructure/prod/provider.hcl`
- **Modules**: `infrastructure/modules/`
- **NixOS configs**: `nix/`
- **Ansible**: `ansible/`
- **Justfile**: `justfile` (all commands)
