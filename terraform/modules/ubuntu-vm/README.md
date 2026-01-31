# Ubuntu VM Module

Terraform module for creating Ubuntu 24.04 LTS VMs from the Packer-built template.

## Features

- Clones from ubuntu-24.04-template (VM ID 9000)
- Sensible defaults for common use cases
- Optional GPU passthrough support
- Cloud-init with SSH key configuration
- DHCP or static IP configuration
- Automatic tagging (ubuntu, terraform, + custom tags)

## Usage

### Basic Example (DHCP)

```hcl
module "web_server" {
  source = "../modules/ubuntu-vm"

  vm_name  = "web-server-01"
  ssh_keys = [file("~/.ssh/id_ed25519.pub")]
}
```

### Static IP Example

```hcl
module "db_server" {
  source = "../modules/ubuntu-vm"

  vm_name       = "db-server-01"
  ssh_keys      = [var.ssh_public_key]
  ipv4_address  = "192.168.0.200/24"
  ipv4_gateway  = "192.168.0.1"
  memory_mb     = 8192
  cpu_cores     = 4
  disk_size_gb  = 100
  tags          = ["database", "production"]
}
```

### GPU Passthrough Example

**⚠️ IMPORTANT**: A physical GPU can only be passed through to **ONE VM at a time**.
Only enable GPU passthrough on a single VM instance.

```hcl
module "ai_workstation" {
  source = "../modules/ubuntu-vm"

  vm_name                 = "ai-workstation"
  ssh_keys                = [var.ssh_public_key]
  gpu_passthrough_enabled = true  # Only set this on ONE VM!
  gpu_mapping_id          = "intel-igpu"
  memory_mb               = 16384
  cpu_cores               = 8
}

# Other VMs should NOT have GPU passthrough enabled
module "web_server" {
  source = "../modules/ubuntu-vm"

  vm_name  = "web-server"
  ssh_keys = [var.ssh_public_key]
  # gpu_passthrough_enabled defaults to false - GPU not needed
}
```

## Requirements

- Proxmox VE 9.x
- bpg/proxmox Terraform provider (~> 0.71)
- Ubuntu 24.04 template (VM ID 9000) created with Packer
- For GPU passthrough: IOMMU enabled and PCI resource mapping configured

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | -------- |
| vm_name | Name of the VM | string | - | yes |
| ssh_keys | List of SSH public keys | list(string) | - | yes |
| node_name | Proxmox node name | string | "pve" | no |
| description | VM description | string | "Ubuntu 24.04 LTS VM" | no |
| template_vm_id | Template VM ID to clone from | number | 9000 | no |
| cpu_cores | Number of CPU cores | number | 2 | no |
| cpu_type | CPU type | string | "host" | no |
| memory_mb | Memory in MB | number | 4096 | no |
| disk_size_gb | Disk size in GB | number | 32 | no |
| datastore_id | Proxmox datastore ID | string | "local-lvm" | no |
| network_bridge | Network bridge | string | "vmbr0" | no |
| network_firewall | Enable firewall | bool | false | no |
| start_on_boot | Start on Proxmox boot | bool | false | no |
| tags | Additional tags | list(string) | [] | no |
| vm_user | VM username | string | "ubuntu" | no |
| ipv4_address | IPv4 address or "dhcp" | string | "dhcp" | no |
| ipv4_gateway | IPv4 gateway | string | null | no |
| dns_servers | DNS servers | list(string) | ["192.168.0.53"] | no |
| gpu_passthrough_enabled | Enable GPU passthrough | bool | false | no |
| gpu_mapping_id | GPU resource mapping ID | string | "intel-igpu" | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| vm_id | VM ID |
| vm_name | VM name |
| ipv4_addresses | IPv4 addresses |
| ipv6_addresses | IPv6 addresses |
| mac_addresses | MAC addresses |

## Defaults

The module uses these sensible defaults:

- **CPU**: 2 cores, host type
- **Memory**: 4096 MB (4 GB)
- **Disk**: 32 GB
- **Network**: DHCP on vmbr0, no firewall
- **Storage**: local-lvm
- **User**: ubuntu
- **DNS**: 192.168.0.53 (Pi-hole)
- **Boot**: Don't start on Proxmox boot
- **Tags**: ubuntu, terraform (always added)

## Notes

- VMs are created with UEFI (OVMF) BIOS
- Cloud-init is used for initial configuration
- Docker is pre-installed from the template
- Network configuration changes are ignored after creation
