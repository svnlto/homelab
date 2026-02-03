# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Homelab infrastructure automation using NixOS, Terraform, and Ansible:

- **Raspberry Pi**: Immutable Pi-hole DNS server (NixOS declarative config)
- **Proxmox VE**: Template-based VM deployment (Packer + Terraform + Ansible)
- **TrueNAS SCALE**: ZFS-based network storage (Terraform VMs + Ansible configuration)

**Critical Design Principle**: Raspberry Pi runs critical network infrastructure (DNS) that must stay operational during
Proxmox maintenance. Pi-hole runs on the Pi, NOT on Proxmox.

## Architecture

### Infrastructure Stack

**Proxmox Nodes** (installed from official ISO):

- `grogu` (r630): 192.168.0.10 - Compute-focused node
- `din` (r730xd): 192.168.0.11 - Storage + compute node
- Configured via Ansible (`ansible/playbooks/configure-existing-proxmox.yml`)

**VM/Container Deployment Workflow**:

1. **Packer Template Building** (15-30 min)
   - Creates VM template inside Proxmox (VM ID 9000)
   - Ubuntu 24.04 with UEFI/OVMF, cloud-init enabled
   - SSH hardening applied via Ansible (password auth disabled)
   - Command: `just packer-build-vm-template`

2. **Terraform VM/Container Cloning** (2-3 min)
   - Clones VMs from template or creates LXC containers
   - Injects SSH keys via cloud-init (VMs) or initialization block (LXC)
   - Most settings baked into main.tf (not variables)
   - Commands: `just tf-apply` / `just tf-destroy`

3. **Ansible Provisioning** (triggered by Terraform)
   - Deploys applications (arr stack, observability)
   - Playbooks: `stack-arr.yml`, `stack-observability.yml`

### NixOS Pi-hole (Raspberry Pi)

**Build Environment**: Vagrant + VMware (macOS limitation)

Pi-hole runs on NixOS for true immutability and atomic updates. Build process:

1. **Start Vagrant VM** (one-time setup):

   ```bash
   just nixos-vm-up
   ```

   - Ubuntu 22.04 VM with Nix installed
   - VMware native shared folders (nix/ directory)
   - Auto garbage collection on boot

2. **Build SD image** (15-20 min first build, 2-5 min incremental):

   ```bash
   just nixos-build-pihole
   ```

   - Copies source files (excludes .vagrant/) to VM's /tmp, builds there
   - Final image copied back to nix/pihole-nixos.img
   - Includes Pi-hole + Unbound in Docker (host networking)

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
- No chroot complexity (Packer required 15+ conditionals)
- Faster incremental builds (Nix cache)

**See**: nix/README.md for complete documentation (460 lines).

**Note**: Packer configs in packer/pihole/ are archived (not used).

### Critical Configuration Requirements

**Packer Template (packer/ubuntu-template/ubuntu-24.04-template.pkr.hcl)**:

- `cloud_init = true` - MUST be enabled for SSH key injection in cloned VMs
- `bios = "ovmf"` and `machine = "q35"` - UEFI boot required
- `cloud_init_storage_pool` - Creates cloud-init drive for template

**Terraform VMs (terraform/proxmox/main.tf)**:

- MUST match template BIOS settings (`bios = "ovmf"`, `machine = "q35"`)
- Requires `efidisk` block (UEFI boot)
- Uses new `disks` block syntax with explicit cloud-init IDE drive
- Settings are baked in (NOT variables) - edit main.tf directly to customize

**Ansible Provisioning (runs in two contexts)**:

1. **During Template Build** (`ansible/playbooks/base-template.yml`):
   - SSH hardening: `PasswordAuthentication no`, `PubkeyAuthentication yes`
   - Installs Docker, Docker Compose, Node Exporter
   - `cloud-init clean --logs --seed` - Ensures cloud-init runs on cloned VMs

2. **After VM Clone** (triggered by Terraform):
   - `ansible/playbooks/arr.yml` - Deploys media automation stack
   - `ansible/playbooks/observability.yml` - Deploys Grafana/Prometheus/Loki
   - Uses `ansible_playbook` resource to trigger provisioning

### LXC Containers vs VMs

**When to use LXC containers:**

- Lightweight services (arr stack, single-purpose apps)
- Don't need full OS isolation
- Want faster boot times and lower memory overhead
- Share kernel with host (more efficient)

**When to use VMs:**

- Need full OS isolation
- Running different OS than host
- Require kernel modules or specific kernel versions
- Need UEFI/SecureBoot

**LXC Container Configuration:**

```hcl
resource "proxmox_virtual_environment_container" "example" {
  node_name    = "pve"
  vm_id        = 201
  unprivileged = true  # Always use unprivileged for security

  features {
    nesting = true  # Required for Docker inside LXC
  }

  mount_point {
    volume = "/mnt/pve/storage"  # Proxmox host path
    path   = "/data"             # Container path
    shared = true
  }
}
```

**Key Differences from VMs:**

- ✓ No cloud-init (use `initialization` block for network config)
- ✓ Direct SSH to root (configure SSH keys in `user_account`)
- ✓ Instant boot (no BIOS/bootloader)
- ✓ Shared kernel with host (lower overhead)
- ✗ Can't run different OS kernel version
- ✗ Less isolation than VMs

**LXC Template Management:**

```bash
# List available templates
pveam available

# Download Debian 12 template
pveam download local debian-12-standard_12.2-1_amd64.tar.zst

# Template path in Terraform
template_file_id = "local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst"
```

### Authentication Flow

**For VMs (cloud-init):**

1. **Template Build**: Packer uses temporary `ubuntu/ubuntu` credentials
2. **Template Hardening**: Ansible disables password auth, enables SSH keys only
3. **VM Clone**: Terraform injects SSH public key via cloud-init
4. **SSH Access**: Uses 1Password SSH agent with Touch ID

**For LXC Containers:**

1. **Container Creation**: Terraform creates container from Debian template
2. **SSH Key Injection**: `user_account.keys` in `initialization` block
3. **Root SSH**: Direct root access (containers don't have sudo user by default)
4. **Provisioning**: Ansible connects as root to install Docker and apps

**SSH Agent Configuration** (both VMs and containers):

- Agent config: `~/.config/1Password/ssh/agent.toml`
- SSH key item name in 1Password: `"proxmox"` (in Personal vault)
- SSH config: `IdentityAgent "/Users/svenlito/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"`

### TrueNAS Infrastructure

**Purpose**: Network storage for Kubernetes PVs, media library, backups

**Architecture**:

- Primary (VMID 300): VM on din (r730xd) with 5×8TB + 24×900GB storage
- Backup (VMID 301): VM on grogu (r630) with 8×3TB storage via MD1200
- Replication: ZFS send/recv over 10G DAC (VLAN 10)

**Deployment is 3-phase** (not fully automated):

#### Phase 1: Deploy VM Shells (Terraform)

```bash
just tf-apply  # Creates VMID 300 + 301
```

Terraform creates:

- Empty VMs with 32GB boot disk + scratch disks
- Network configuration
- **Does NOT** connect real storage (manual next)

#### Phase 2: Storage Passthrough (Manual via Proxmox UI)

TrueNAS needs access to physical disks. Via Proxmox UI:

1. **Primary (VMID 300 on din)**:
   - Hardware → Add → PCI Device
   - Pass through H330 Mini (5×8TB internal drives)
   - Pass through LSI 9201-8e (MD1220 shelf, 24×900GB)

2. **Backup (VMID 301 on grogu)**:
   - Hardware → Add → PCI Device
   - Pass through MD1200 controller (8×3TB)

**Why manual**: Terraform can't automate PCIe passthrough reliably.

#### Phase 3: Pool Creation (Manual via midclt)

SSH into TrueNAS and create ZFS pools:

```bash
# Primary TrueNAS
ssh admin@192.168.0.13

# Create bulk pool (5×8TB RAIDZ2 + SLOG mirror)
midclt call pool.create '{...}'  # See docs/truenas-ansible-setup.md Part 5

# Create fast pool (4×6-wide RAIDZ2)
midclt call pool.create '{...}'
```

**Why manual**: arensb.truenas collection doesn't support pool creation.

#### Phase 4: Configure Datasets/Shares (Ansible)

Once pools exist, Ansible configures everything else:

```bash
# Create datasets, shares, users, snapshots, scrubs, SMART
ansible-playbook ansible/playbooks/truenas-setup.yml

# Setup ZFS replication (SSH keys + tasks)
ansible-playbook ansible/playbooks/truenas-replication.yml
```

**Ansible creates:**

- Datasets: bulk/media, fast/kubernetes, fast/databases, etc.
- NFS shares: for Kubernetes (democratic-csi), Jellyfin
- SMB shares: Time Machine backups
- Snapshot tasks: hourly (databases), daily (media)
- Scrub tasks: weekly pool validation
- Replication: din → grogu over 10G

**See**: docs/truenas-ansible-setup.md for complete design (1200+ lines).

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

### TrueNAS Configuration

```bash
# Deploy TrueNAS VMs (creates empty shells)
just tf-apply

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

# Manual pool creation (SSH into TrueNAS first)
# See: docs/truenas-ansible-setup.md Part 5
```

### VM/Container Deployment Workflow

```bash
# 1. Build VM template inside Proxmox (15-30 min)
just packer-build-vm-template

# 2. Deploy VMs from template (2-3 min)
just tf-apply

# 3. Destroy VMs
just tf-destroy
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

## File Structure

```text
homelab/
├── nix/                                   # NixOS configurations
│   ├── Vagrantfile                        # Ubuntu VM for building (macOS requirement)
│   ├── flake.nix                          # NixOS flake (SD image builder)
│   ├── rpi-pihole/                        # Pi-hole NixOS config
│   │   ├── configuration.nix              # System config
│   │   ├── hardware.nix                   # Raspberry Pi hardware
│   │   └── pihole.nix                     # Pi-hole + Unbound services
│   └── common/
│       └── constants.nix                  # Shared constants (versions, timezone)
│
├── packer/
│   └── proxmox-templates/                 # VM templates (built inside Proxmox)
│       ├── ubuntu-24.04-template.pkr.hcl  # Proxmox template builder
│       └── http/                          # Autoinstall configs (user-data, meta-data)
│
├── terraform/
│   ├── modules/ubuntu-vm/                 # Reusable VM module (40+ parameters)
│   │   ├── main.tf                        # VM resource definition
│   │   ├── variables.tf                   # Module inputs
│   │   └── outputs.tf                     # VM metadata (IP, ID, MAC)
│   └── proxmox/                           # Root module
│       ├── providers.tf                   # bpg/proxmox provider 0.89.1
│       ├── main.tf                        # Provider configuration
│       ├── locals.tf                      # Network ranges, IPs, node names
│       ├── _truenas.tf                    # TrueNAS Primary VM (VMID 300)
│       ├── _truenas-backup.tf             # TrueNAS Backup VM (VMID 301)
│       ├── _talos-homelab-cluster.tf      # Kubernetes cluster config
│       ├── variables.tf                   # Sensitive vars only
│       └── terraform.tfvars               # SSH public key (GITIGNORED)
│
├── ansible/
│   ├── inventory.ini                      # Proxmox node inventory (grogu, din)
│   ├── playbooks/
│   │   ├── configure-existing-proxmox.yml # Configure installed Proxmox nodes
│   │   ├── packer-base-vm.yml             # Template provisioning (SSH, Docker)
│   │   ├── stack-arr.yml                  # Full arr media stack
│   │   └── stack-observability.yml        # Grafana/Prometheus/Loki
│   └── roles/
│       ├── arr/                           # Full media automation stack role
│       ├── observability/                 # Monitoring stack role
│       ├── proxmox_configure/             # Proxmox configuration (nag removal, PCIe)
│       └── security/                      # SSH hardening
│
├── .envrc                                 # Loads .env and exports TF_VAR_*
├── .env                                   # API tokens (GITIGNORED)
├── flake.nix                              # Nix environment (pinned versions)
└── justfile                               # Command runner
```

## Environment Variables

**Authentication** (stored in `.env`, auto-loaded by direnv):

```bash
PROXMOX_TOKEN_ID="root@pam!terraform"
PROXMOX_TOKEN_SECRET="<uuid>"
```

**Auto-exported by .envrc**:

- `TF_VAR_proxmox_api_token_id` - For Terraform
- `TF_VAR_proxmox_api_token_secret` - For Terraform
- `PROXMOX_TOKEN_ID` - For Packer (via `env("PROXMOX_TOKEN_ID")`)
- `PROXMOX_TOKEN_SECRET` - For Packer (via `env("PROXMOX_TOKEN_SECRET")`)

## Tool Versions

Pinned via Nix flakes for reproducibility:

- **Packer**: 1.14.3 (pinned nixpkgs commit)
- **Terraform**: 1.14.1 (from nixpkgs-terraform)
- **Proxmox Provider**: 3.0.2-rc06 (Telmate)
- **Ansible**: Latest from nixpkgs-unstable

## Common Issues

### VM stuck at SeaBIOS boot screen

- **Cause**: Terraform missing UEFI configuration
- **Fix**: Ensure `bios = "ovmf"`, `machine = "q35"`, and `efidisk` block present

### SSH key authentication not working

- **Cause**: Cloud-init not enabled in template OR 1Password agent not loading key
- **Fix**:
  1. Verify `cloud_init = true` in Packer template
  2. Check `ssh-add -l` shows Proxmox key
  3. Update `~/.config/1Password/ssh/agent.toml` if needed

### Cloud-init not running on cloned VMs

- **Cause**: Template wasn't properly cleaned
- **Fix**: Ansible must run `cloud-init clean --logs --seed` during template build

### TrueNAS pools not visible after VM creation

- **Cause**: Terraform creates VM shell but doesn't connect physical storage
- **Fix**: Manual HBA passthrough via Proxmox UI (Hardware → Add → PCI Device)
- **Then**: SSH into TrueNAS and create pools via midclt commands
- **See**: docs/truenas-ansible-setup.md Part 5 for pool creation

### Ansible TrueNAS playbook fails with dataset errors

- **Cause**: Pools don't exist yet (arensb.truenas can't create pools)
- **Fix**: Create pools manually via midclt before running ansible playbooks
- **Verify pools exist**: `midclt call pool.query` on TrueNAS

## Network Architecture

See [docs/network-architecture.md](docs/network-architecture.md) for comprehensive network documentation including:

- VLAN architecture (Infrastructure + Kubernetes VLANs 30-32)
- Current single-router setup and future two-switch expansion
- Inter-VLAN routing rules and firewall policies
- Kubernetes multi-cluster network design
- Proxmox bridge configuration
- Traffic flow examples

```text
Internet → Router (192.168.0.1)
              ↓
    ┌─────────┼─────────┐
    ↓                   ↓
Pi-hole DNS      Proxmox Cluster
192.168.0.53     grogu (r630) + din (r730xd)
(Raspberry Pi)        ↓
    ↓           ┌─────┴─────┐
Network-wide    ↓           ↓
DNS Filtering  grogu       din
            (Compute)  (Storage+Compute)
          192.168.0.10   192.168.0.11
                ↓           ↓
                └── 10GbE ──┘
               VLAN 10 Storage
              10.10.10.10/24

                    din
                 (r730xd)
                      ↓
                   MD1220
                 Disk Shelf
                (24x SFF)
             SFF-8088 SAS Cables
```

**IP Assignments**:

- Router/Gateway (VLAN 20): 192.168.0.1
- Pi-hole DNS: 192.168.0.53 (Raspberry Pi)
- grogu (r630): 192.168.0.10 (VLAN 20 mgmt), 10.10.10.10 (VLAN 10 storage)
- din (r730xd): 192.168.0.11 (VLAN 20 mgmt), 10.10.10.11 (VLAN 10 storage)
- Template VM: ID 9000

**Network Architecture**:

- VLAN 1 (Management): 10.10.1.0/24 - iDRAC, switch management
- VLAN 10 (Storage): 10.10.10.0/24 - NFS/iSCSI, high-bandwidth storage traffic
- VLAN 20 (LAN): 192.168.0.0/24 - Infrastructure VMs, clients
- VLAN 30 (K8s Shared Services): 10.0.1.0/24 - Infrastructure cluster (SigNoz, ingress, ArgoCD)
- VLAN 31 (K8s Apps): 10.0.2.0/24 - Production apps cluster (Jellyfin, Immich, etc.)
- VLAN 32 (K8s Test): 10.0.3.0/24 - Testing/staging cluster

**Infrastructure VMs:**

- TrueNAS Primary: 192.168.0.13 (VMID 300, on din), 10.10.10.13 (VLAN 10 storage)
- TrueNAS Backup: 192.168.0.14 (VMID 301, on grogu), 10.10.10.14 (VLAN 10 storage)

**Kubernetes Workloads** (K8s-first approach - all production on K8s):

- Shared Services (VLAN 30): SigNoz, Nginx Ingress, ArgoCD, cert-manager, Vault
- Apps (VLAN 31): Jellyfin, Sonarr, Radarr, Prowlarr, Immich, Nextcloud, Home Assistant
- Test (VLAN 32): Staging and experimental deployments

**Hardware:**

- r730xd: Dell PowerEdge R730xd (2U, 16x LFF + 2x SFF)
  - CPUs: 2x E5-2680 v3 (12C/24T each = 24C/48T total)
  - Boot: 2x SATA SSD in rear SFF slots (Proxmox + TrueNAS VM)
  - Dell H330 Mini (IT mode) → 5x 8TB LFF drives (internal)
  - LSI 9201-8e → DS2246 disk shelf (24x SFF drives)
  - 10GbE SFP+ → Direct connection to r630
- r630: Dell PowerEdge R630 (1U, 8x SFF, 3x low-profile PCIe)
  - CPUs: 2x E5-2699 v3 (18C/36T each = 36C/72T total)
  - Boot: 1x SATA drive in optical bay (Proxmox)
  - GPU: Intel Arc A310 Eco (low-profile, Jellyfin transcoding)
  - 2x 10GbE SFP+ (onboard NDC) → Direct connection to r730xd
- DS2246: NetApp disk shelf with 24x 2.5" SFF bays
  - 2x IOM6 modules for SAS connectivity
  - Dual SFF-8088 cables to r730xd (redundant paths)

**Total Cluster:** 60C/120T, 192-320GB RAM, Intel Arc A310 GPU

## Terraform Module Pattern

### Using the ubuntu-vm Module

To add a new VM, create a new `.tf` file in `terraform/proxmox/` (e.g., `_newservice.tf`):

```hcl
module "newservice_server" {
  source = "../modules/ubuntu-vm"

  # Required settings
  proxmox_node     = "pve"
  template_vm_id   = 9000
  vm_name          = "newservice-server"
  vm_id            = 201

  # Hardware
  cpu_cores        = 2
  memory_mb        = 4096
  disk_size_gb     = 50

  # Network
  ipv4_address     = "192.168.0.202/24"
  ipv4_gateway     = "192.168.0.1"

  # SSH
  ssh_public_key   = var.ssh_public_key

  # Tags
  tags             = ["ubuntu", "newservice", "production"]
}

# Trigger Ansible provisioning after VM is created
resource "ansible_playbook" "newservice" {
  playbook   = "${path.module}/../../ansible/playbooks/newservice.yml"
  name       = module.newservice_server.ipv4_addresses[0][0]

  extra_vars = {
    ansible_user = "ubuntu"
  }

  depends_on = [module.newservice_server]
}
```

**Module Benefits:**

- DRY (Don't Repeat Yourself) - common config in one place
- Consistent VM configuration across deployments
- Easy to add new VMs without duplicating code
- Centralized updates (fix once in module, applies everywhere)

## Development Notes

### Raspberry Pi ARM Building

**macOS Limitation**: Docker Desktop cannot mount loop devices, so ARM image building requires Vagrant + QEMU:

1. Vagrantfile creates Ubuntu 22.04 VM with privileged access
2. VM runs `mkaczanowski/packer-builder-arm` Docker container
3. Container builds ARM image with loop device access
4. Image copied back to host via rsync

### Terraform Variable Strategy

Previously used extensive variables (vm_name, vm_cores, vm_memory, etc.). Now most settings are baked directly into
`main.tf` to simplify template usage. Only sensitive values remain as variables:

- `proxmox_api_token_id`
- `proxmox_api_token_secret`
- `ssh_public_key`

To customize VMs, edit `main.tf` directly rather than managing variables.

### SSH Key Management

1Password SSH agent provides Touch ID authentication:

- Private key stored in 1Password (item: "proxmox")
- Public key in `terraform.tfvars` (injected via cloud-init)
- Agent socket: `~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock`

## References

- Proxmox API: <https://192.168.0.10:8006/api2/json> (grogu - primary node)
- Packer Proxmox Builder: <https://developer.hashicorp.com/packer/plugins/builders/proxmox/iso>
- Terraform Proxmox Provider: <https://github.com/bpg/terraform-provider-proxmox>
- Packer ARM Builder: <https://github.com/mkaczanowski/packer-builder-arm>

## Important Implementation Details

### Memory Usage (Linux Cache Behavior)

When checking VM memory in Proxmox, you may see high usage (e.g., 3.8GB of 4GB). This is **normal Linux behavior**:

```text
Total: 3.8GB
Used:  859MB  ← Actual application usage
Cache: 3.0GB  ← File system cache (automatically freed when needed)
```

**Key insight**: Linux uses "free" RAM for caching to improve performance. This cache is immediately released if
applications need memory. Check `available` column, not `used`, to see true memory pressure.
