# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Homelab infrastructure automation using Packer, Terraform, and Ansible:

- **Raspberry Pi**: Immutable Pi-hole DNS server image (Packer + ARM builder)
- **Proxmox VE**: Template-based VM deployment (Packer + Terraform + Ansible)

**Critical Design Principle**: Raspberry Pi runs critical network infrastructure (DNS) that must stay operational during
Proxmox maintenance. Pi-hole runs on the Pi, NOT on Proxmox.

## Architecture

### Two Infrastructure Paths

#### Path 1: Bare-Metal Proxmox Installation

1. **Build Bootable Image** (`packer/bare-metal/`)
   - Downloads Debian cloud image
   - Provisions with Ansible (installs Proxmox VE)
   - Creates bootable raw disk image
   - Build time: 15-20 min (Apple Silicon)

2. **Flash to Physical Disk**

   ```bash
   just packer-build-bare-metal
   just bare-metal-flash /dev/rdiskX
   ```

3. **Boot Dell Server**
   - Boot r630/r730xd from USB/SSD
   - Proxmox VE ready immediately (no installation wizard)

4. **Use Case**: Initial Proxmox cluster setup on bare metal

#### Path 2: VM Template in Proxmox

1. **Packer Template Building** (15-30 min)
   - Creates VM template inside Proxmox (VM ID 9000)
   - Ubuntu 24.04 with UEFI/OVMF, cloud-init enabled
   - SSH hardening applied via Ansible (password auth disabled)

2. **Terraform VM Cloning** (2-3 min)
   - Clones VMs from template
   - Injects SSH keys via cloud-init
   - Most settings baked into main.tf (not variables)

3. **Ansible Provisioning**
   - Deploys applications (arr stack, observability)

4. **Use Case**: Rapid VM deployment for services

### Bare-Metal vs VM Template Workflows

**Common Confusion**: This project has TWO distinct Packer workflows:

| Workflow        | Purpose                      | Output                     | Deploy Method    | Command                         |
| --------------- | ---------------------------- | -------------------------- | ---------------- | ------------------------------- |
| **Bare-Metal**  | Install Proxmox on servers   | `.raw.gz` image            | Flash to USB/SSD | `just packer-build-bare-metal`  |
| **VM Template** | Create reusable VM templates | Proxmox template (ID 9000) | Terraform clone  | `just packer-build-vm-template` |

**Key Difference:**

- Bare-metal = Build **Proxmox itself** (the hypervisor)
- VM template = Build **VMs to run on Proxmox** (services like arr stack)

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

## Essential Commands

### Development Environment

```bash
# Enter Nix shell (auto-loads with direnv)
nix develop

# All commands use direnv to load .env credentials
just --list
```

### Bare-Metal Proxmox Node Workflow

```bash
# 1. Start build VM (one time)
just bare-metal-vm-up

# 2. Build bootable image (15-20 min)
just packer-build-bare-metal

# 3. Flash to USB/SSD
just bare-metal-flash /dev/rdiskX

# 4. Boot Dell server from USB/SSD
# Proxmox VE ready immediately!
```

### Proxmox VM Template Workflow

```bash
# 1. Build VM template inside Proxmox (15-30 min)
just packer-build-vm-template

# 2. Deploy VMs from template (2-3 min)
just tf-apply

# 3. Destroy VMs
just tf-destroy
```

### Raspberry Pi Workflow

```bash
# 1. Start build VM (one time)
just pihole-vm-up

# 2. Build Pi-hole image (30-60 min)
just packer-build-pihole

# 3. Flash to SD card
just pihole-flash /dev/rdiskX
```

## File Structure

```text
homelab/
├── packer/
│   ├── bare-metal/                        # Bare-metal Proxmox installer (bootable images)
│   │   ├── proxmox-node.pkr.hcl          # Cloud image-based builder
│   │   ├── variables.pkr.hcl              # Build configuration
│   │   ├── cloud-init/                    # Cloud-init for initial boot
│   │   ├── Vagrantfile                    # Apple Silicon build VM
│   │   └── README.md
│   │
│   ├── pihole/                            # Pi-hole for Raspberry Pi
│   │   ├── rpi-pihole.pkr.hcl
│   │   └── ...
│   │
│   ├── proxmox-templates/                 # VM templates (built inside Proxmox)
│   │   ├── ubuntu-24.04-template.pkr.hcl # Proxmox template builder
│   │   └── http/                          # Autoinstall configs (user-data, meta-data)
│   │
│   └── _archive/                          # Historical reference
│       └── x86-builder/                   # Preseed installer approach (archived)
│
├── terraform/
│   ├── modules/ubuntu-vm/                 # Reusable VM module (40+ parameters)
│   │   ├── main.tf                        # VM resource definition
│   │   ├── variables.tf                   # Module inputs
│   │   └── outputs.tf                     # VM metadata (IP, ID, MAC)
│   └── proxmox/                           # Root module
│       ├── providers.tf                   # bpg/proxmox provider 0.89.1
│       ├── main.tf                        # Provider configuration
│       ├── _arrstack.tf                   # Arr LXC container (192.168.1.50)
│       ├── _observability.tf              # Monitoring VM (192.168.1.60)
│       ├── variables.tf                   # Sensitive vars only
│       └── terraform.tfvars               # SSH public key (GITIGNORED)
│
├── ansible/
│   ├── playbooks/
│   │   ├── base-template.yml              # Template hardening (SSH, Docker)
│   │   ├── packer-proxmox-node.yml        # Bare-metal Proxmox (installs PVE)
│   │   ├── packer-pihole.yml              # Pi-hole + Unbound deployment
│   │   ├── stack-arr.yml                  # Full arr media stack
│   │   └── observability.yml              # Grafana/Prometheus/Loki
│   └── roles/
│       ├── pihole/                        # Pi-hole + Unbound role
│       ├── arr/                           # Full media automation stack role
│       └── observability/                 # Monitoring stack role
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

## Network Architecture

```text
Internet → Router (192.168.1.1)
              ↓
    ┌─────────┼─────────┐
    ↓                   ↓
Pi-hole DNS      Proxmox Cluster
192.168.1.2      r630 + r730xd
(Raspberry Pi)        ↓
    ↓           ┌─────┴─────┐
Network-wide    ↓           ↓
DNS Filtering  r630        r730xd
            (Compute)  (Storage+Compute)
           192.168.1.XX  192.168.1.76
                ↓           ↓
                └── 10GbE ──┘
                   DAC Cable
                   10.0.0.0/30

                   r730xd
                      ↓
                   DS2246
                 Disk Shelf
                (24x SFF)
             SFF-8088 SAS Cables
```

**IP Assignments**:

- Router/Gateway: 192.168.1.1
- Pi-hole: 192.168.1.2 (Raspberry Pi #2)
- Tailscale: 192.168.1.100 (Raspberry Pi #1, if configured)
- r730xd (Proxmox + TrueNAS VM): 192.168.1.76 (mgmt), 10.0.0.1/30 (storage)
- r630 (Proxmox): 192.168.1.XX (mgmt), 10.0.0.2/30 (storage/cluster)
- Template VM: ID 9000

**LXC Containers:**

- arr-stack: 192.168.1.50 (VMID 200) - Full media automation suite

**VMs:**

- monitoring-server: 192.168.1.60 (static, observability)
- truenas: 192.168.1.76 (VMID 300) - Storage VM on r730xd

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
  ipv4_address     = "192.168.1.52/24"
  ipv4_gateway     = "192.168.1.1"

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

- Proxmox API: <https://192.168.1.37:8006/api2/json>
- Packer Proxmox Builder: <https://developer.hashicorp.com/packer/plugins/builders/proxmox/iso>
- Terraform Proxmox Provider: <https://github.com/bpg/terraform-provider-proxmox>
- Packer ARM Builder: <https://github.com/mkaczanowski/packer-builder-arm>

## Important Implementation Details

### Ansible Chroot Provisioning (Pi-hole)

When building the Pi-hole image, Ansible runs **inside a chroot environment** (no running systemd or Docker daemon).
Tasks must be chroot-aware:

**Problem**: Can't use `systemd` or `docker` modules in chroot
**Solution**: Use `packer_build` variable to conditionally skip/modify tasks

```yaml
# Skip during Packer build (chroot)
- name: Enable systemd-timesyncd
  ansible.builtin.systemd:
    name: systemd-timesyncd
    enabled: true
    state: started
  when: not packer_build | default(false)

# Manual service enabling for Packer build
- name: Enable node_exporter (packer build)
  ansible.builtin.file:
    src: /usr/lib/systemd/system/prometheus-node-exporter.service
    dest: /etc/systemd/system/multi-user.target.wants/prometheus-node-exporter.service
    state: link
  when: packer_build | default(false)
```

**Key Constraints in Chroot:**

- ❌ Cannot run `systemctl` commands
- ❌ Cannot start/stop services
- ❌ Cannot run Docker containers
- ✅ Can install packages via `apt`
- ✅ Can create files and directories
- ✅ Can create systemd unit files
- ✅ Can manually create symlinks in `/etc/systemd/system/multi-user.target.wants/`

**Packer passes the flag:**

```hcl
provisioner "shell" {
  inline = [
    "ansible-playbook pihole.yml --extra-vars 'packer_build=true'"
  ]
}
```

### Memory Usage (Linux Cache Behavior)

When checking VM memory in Proxmox, you may see high usage (e.g., 3.8GB of 4GB). This is **normal Linux behavior**:

```text
Total: 3.8GB
Used:  859MB  ← Actual application usage
Cache: 3.0GB  ← File system cache (automatically freed when needed)
```

**Key insight**: Linux uses "free" RAM for caching to improve performance. This cache is immediately released if
applications need memory. Check `available` column, not `used`, to see true memory pressure.
