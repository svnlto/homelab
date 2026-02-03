# Infrastructure as Code (Terragrunt)

This directory contains Terragrunt-based infrastructure configuration for the homelab.

## Directory Structure

```text
infrastructure/
├── globals.hcl                  # Single source of truth (VLANs, IPs, versions)
├── root.hcl                     # Remote state configuration (local backend)
│
├── mikrotik/                    # MikroTik CRS router configuration
│   ├── provider.hcl             # RouterOS provider
│   ├── base/                    # VLANs, bridge, IPs, routing
│   ├── dhcp/                    # Per-VLAN DHCP servers (4 VLANs)
│   ├── firewall/                # Zone-based firewall rules
│   └── dns/                     # DNS forwarding to Pi-hole
│
├── proxmox/                     # Proxmox VM/container management
│   ├── provider.hcl             # Proxmox provider
│   ├── truenas-primary/         # TrueNAS Primary VM (VMID 300)
│   └── truenas-backup/          # TrueNAS Backup VM (VMID 301)
│
└── modules/                     # Reusable Terraform modules
    ├── truenas-vm/              # TrueNAS VM deployment module
    └── talos-cluster/           # Talos Kubernetes cluster module
```

## Key Files

### globals.hcl

Single source of truth containing:

- VLAN definitions (management, storage, LAN, K8s VLANs)
- IP address assignments (infrastructure IPs, DHCP pools)
- Proxmox configuration (nodes, API URL, template ID)
- MikroTik configuration (hostname, interfaces, bridge)
- Software versions (TrueNAS, etc.)

### root.hcl

Remote state configuration using Backblaze B2 (S3-compatible backend):

```text
Bucket: svnlto-homelab-terraform-state
Region: eu-central-003 (Amsterdam datacenter)
Endpoint: s3.eu-central-003.backblazeb2.com

State files:
├── prod/resource-pools/terraform.tfstate
├── prod/iso-images/terraform.tfstate
├── prod/storage/truenas-primary/terraform.tfstate
├── prod/storage/truenas-backup/terraform.tfstate
└── prod/mikrotik/.../terraform.tfstate (when deployed)
```

**Benefits**: Geo-redundant storage, version history, team collaboration, encrypted at rest.

## Module Structure

Each Terragrunt module follows standard conventions:

```text
infrastructure/<category>/<module>/
├── terragrunt.hcl     # Terragrunt config (loads globals, includes provider)
├── variables.tf       # Input variable declarations
├── main.tf            # Resource definitions
└── outputs.tf         # Output value declarations
```

## Proxmox Host Networking

**Important**: Proxmox host network bridges (vmbr10, vmbr20, vmbr30, vmbr31, vmbr32) are
configured via **Ansible**, not Terragrunt.

This is one-time host-level setup:

```bash
# Configure all Proxmox hosts
just ansible-configure-all

# Or run directly
ansible-playbook ansible/playbooks/configure-proxmox-networking.yml
```

**Why Ansible for this?**

- One-time per-host configuration (not per-VM)
- Host-level networking requires careful handling
- Already well-implemented in Ansible
- Avoids Terraform state complexity for infrastructure setup

**Bridges configured:**

- `vmbr10` - VLAN 10 (Storage) - grogu: 10.10.10.10, din: 10.10.10.11
- `vmbr20` - VLAN 20 (LAN/Management) - grogu: 192.168.0.10, din: 192.168.0.11
- `vmbr30` - VLAN 30 (K8s Shared Services) - No IP (VMs only)
- `vmbr31` - VLAN 31 (K8s Apps) - No IP (VMs only)
- `vmbr32` - VLAN 32 (K8s Test) - No IP (VMs only)

## Usage

### Prerequisites

```bash
# Load Nix environment (includes Terragrunt)
nix develop
# or with direnv:
direnv allow
```

### Common Commands

```bash
# Initialize all modules
cd infrastructure
terragrunt run-all init

# Plan changes across all modules
terragrunt run-all plan

# Apply specific module
cd infrastructure/proxmox/truenas-primary
terragrunt apply

# Apply all modules (careful!)
cd infrastructure
terragrunt run-all apply

# Validate configurations
just tg-validate

# Backup state
just tg-backup
```

### Deploying New VMs

1. Create new module directory:

   ```bash
   mkdir -p infrastructure/proxmox/my-new-vm
   ```

2. Create `terragrunt.hcl` that:
   - Includes `root.hcl` and `provider.hcl`
   - Loads values from `globals.hcl`
   - Defines inputs (VM config)

3. Create standard Terraform files:
   - `variables.tf` - Variable declarations
   - `main.tf` - Resource definitions
   - `outputs.tf` - Outputs

4. Initialize and apply:

   ```bash
   cd infrastructure/proxmox/my-new-vm
   terragrunt init
   terragrunt plan
   terragrunt apply
   ```

## Migration Status

**Phase 1**: ✅ Complete - Setup and foundation
**Phase 2**: ✅ Complete - Proxmox migration (VMs recreated, no state import)
**Phase 3**: ⏳ Setup complete - MikroTik integration (awaiting router setup)
**Phase 4**: ✅ Complete - B2 remote state migration (2026-02-03)
**Phase 5**: 🔜 Not started - Documentation and cleanup

See `PHASE_STATUS.md` for detailed status.

## Rollback

Old Terraform configs archived in:

```text
archive/terraform-legacy-20260203/
```

To rollback Terragrunt changes:

```bash
# Destroy all Terragrunt-managed resources
cd infrastructure
terragrunt run-all destroy

# Restore old terraform (if needed)
cd archive/terraform-legacy-20260203
terraform init
terraform plan
```

## Next Steps

1. **Deploy VMs** (if not already done):

   ```bash
   cd infrastructure/proxmox/truenas-primary && terragrunt apply
   cd ../truenas-backup && terragrunt apply
   ```

2. **MikroTik Setup** (see `mikrotik/SETUP.md`):
   - Physical router setup
   - Create terraform user
   - Enable REST API
   - Configure credentials in `.env`

3. **Apply MikroTik Config** (during maintenance window):

   ```bash
   cd infrastructure/mikrotik/base && terragrunt apply
   cd ../dhcp/vlan-20-lan && terragrunt apply
   # Continue with other VLANs, firewall, DNS
   ```

4. **Migrate to B2 Remote State** (once credentials ready):
   - Update `root.hcl` with B2 backend
   - Run `terragrunt run-all init -migrate-state`
