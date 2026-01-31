# Proxmox VM Deployment

Terraform configuration for deploying VMs on Proxmox from Packer-built templates.

## Prerequisites

1. **Packer template built**: Run `just packer-build-proxmox` (creates template VM 9000)
2. **Environment configured**: `.env` with Proxmox API tokens (see root README)

## Quick Start

```bash
# Initialize and deploy
just tf-init
just tf-apply

# Destroy VMs
just tf-destroy
```

## Architecture

This uses the **ubuntu-vm module** for consistent VM deployment:

```text
packer/proxmox-templates/     → Builds template (VM 9000)
         ↓
terraform/modules/ubuntu-vm/  → Reusable VM module
         ↓
terraform/*.tf                → VM definitions (arr, TrueNAS, Talos, etc.)
```

## Adding New VMs

Create a new `.tf` file (e.g., `_newservice.tf`):

```hcl
module "newservice_server" {
  source = "./modules/ubuntu-vm"

  proxmox_node     = "pve"
  template_vm_id   = 9000
  vm_name          = "newservice-server"
  vm_id            = 202

  cpu_cores        = 2
  memory_mb        = 4096
  disk_size_gb     = 50

  ipv4_address     = "192.168.0.202/24"
  ipv4_gateway     = "192.168.0.1"

  ssh_public_key   = var.ssh_public_key
  tags             = ["ubuntu", "newservice"]
}

resource "ansible_playbook" "newservice" {
  playbook   = "${path.module}/../ansible/playbooks/newservice.yml"
  name       = module.newservice_server.ipv4_addresses[0][0]
  extra_vars = { ansible_user = "ubuntu" }
  depends_on = [module.newservice_server]
}
```

## Current VMs/Containers

| VM/Container | IP | Purpose |
| ------------ | -- | ------- |
| arr-stack (LXC) | 192.168.0.200 | Media automation (Sonarr, Radarr, etc.) |
| TrueNAS SCALE (VM) | 192.168.0.13 (mgmt), 10.10.10.13 (storage) | ZFS storage (NFS/iSCSI) |
| Talos K8s Cluster | 10.0.1.10-23 | Kubernetes cluster (observability via SigNoz) |

## Module Documentation

See `terraform/modules/ubuntu-vm/README.md` for all available parameters.

## Troubleshooting

**Template not found**: Build it first with `just packer-build-proxmox`

**SSH key auth fails**: Verify `ssh_public_key` is set in `terraform.tfvars` and matches 1Password agent

**Cloud-init not running**: Template must have `cloud_init = true` (already configured in Packer)
