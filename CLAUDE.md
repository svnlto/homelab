# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Homelab infrastructure automation using Packer, Terraform, and Ansible:

- **Raspberry Pi**: Immutable Pi-hole DNS server image (Packer + ARM builder)
- **Proxmox VE**: Template-based VM deployment (Packer + Terraform + Ansible)

**Critical Design Principle**: Raspberry Pi runs critical network infrastructure (DNS) that must stay operational during
Proxmox maintenance. Pi-hole runs on the Pi, NOT on Proxmox.

## Architecture

### Three-Phase Build System

1. **Packer Template Building** (15-30 min)
   - Creates immutable base template (VM ID 9000)
   - Ubuntu 24.04 with UEFI/OVMF, cloud-init enabled
   - SSH hardening applied via Ansible (password auth disabled)

2. **Terraform VM Cloning** (2-3 min)
   - Clones VMs from template
   - Injects SSH keys via cloud-init
   - Most settings baked into main.tf (not variables)

3. **Ansible Provisioning**
   - Runs during Packer build only
   - Hardens template with SSH key-only authentication

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

### Authentication Flow

1. **Template Build**: Packer uses temporary `ubuntu/ubuntu` credentials
2. **Template Hardening**: Ansible disables password auth, enables SSH keys only
3. **VM Clone**: Terraform injects SSH public key via cloud-init
4. **SSH Access**: Uses 1Password SSH agent with Touch ID
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

### Proxmox Workflow

```bash
# 1. Build template (one time, 15-30 min)
just packer-build-proxmox

# 2. Deploy VMs from template (2-3 min)
just tf-apply

# 3. Destroy VMs
just tf-destroy
```

### Raspberry Pi Workflow

```bash
# Start Vagrant VM for ARM building (macOS requirement)
just vagrant-up

# Build Pi-hole image (30-60 min)
just packer-build-pihole

# Flash to SD card
sudo dd if=output/rpi-pihole.img of=/dev/rdiskX bs=4M status=progress

# SSH to Pi-hole
just ssh-pihole
```

## File Structure

```text
homelab/
├── packer/
│   ├── ubuntu-template/
│   │   ├── ubuntu-24.04-template.pkr.hcl  # Proxmox template builder
│   │   └── http/                          # Autoinstall configs (user-data, meta-data)
│   └── rpi-pihole.pkr.hcl                 # Pi-hole ARM image
│
├── terraform/
│   ├── modules/ubuntu-vm/                 # Reusable VM module (40+ parameters)
│   │   ├── main.tf                        # VM resource definition
│   │   ├── variables.tf                   # Module inputs
│   │   └── outputs.tf                     # VM metadata (IP, ID, MAC)
│   └── proxmox/                           # Root module
│       ├── providers.tf                   # bpg/proxmox provider 0.89.1
│       ├── main.tf                        # Provider configuration
│       ├── _arrstack.tf                   # Media server VM (192.168.1.50)
│       ├── _observability.tf              # Monitoring VM (192.168.1.51)
│       ├── variables.tf                   # Sensitive vars only
│       └── terraform.tfvars               # SSH public key (GITIGNORED)
│
├── ansible/
│   ├── playbooks/
│   │   ├── base-template.yml              # Template hardening (SSH, Docker)
│   │   ├── pihole.yml                     # Pi-hole + Unbound deployment
│   │   ├── arr.yml                        # Media automation stack
│   │   └── observability.yml              # Grafana/Prometheus/Loki
│   └── roles/
│       ├── pihole/                        # Pi-hole + Unbound role
│       ├── arr/                           # Media server role
│       └── observability/                 # Monitoring stack role
│
├── .envrc                                 # Loads .env and exports TF_VAR_*
├── .env                                   # API tokens (GITIGNORED)
├── flake.nix                              # Nix environment (pinned versions)
├── Vagrantfile                            # ARM build VM (macOS workaround)
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
Pi-hole DNS         Proxmox VE
192.168.1.2         192.168.1.37
(Raspberry Pi)      (P520 Server)
    ↓                   ↓
Network-wide        VM Infrastructure
DNS Filtering       (Cloned from Template)
```

**IP Assignments**:

- Router/Gateway: 192.168.1.1
- Pi-hole: 192.168.1.2 (Raspberry Pi #2)
- Tailscale: 192.168.1.100 (Raspberry Pi #1, if configured)
- Proxmox: 192.168.1.37
- Template VM: ID 9000
- arr-server: 192.168.1.50 (static, media automation)
- monitoring-server: 192.168.1.51 (static, observability)

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
