# TrueNAS VM Module

Reusable Terraform module for deploying TrueNAS SCALE VMs on Proxmox.

## Features

- Automatic ISO download and VM creation
- UEFI boot with OVMF
- Virtio storage and network drivers
- Optional dual network interfaces (management + storage VLANs)
- Optional PCI passthrough for HBAs
- Optional cloud-init network configuration
- Lifecycle management with configurable ignore_changes

## Usage

### TrueNAS Primary (with HBA passthrough)

```hcl
module "truenas_primary" {
  source = "../../modules/truenas-vm"

  # Basic Configuration
  node_name    = "grogu"
  vm_id        = 300
  vm_name      = "truenas-server"
  vm_description = "TrueNAS SCALE Primary Storage"
  tags         = ["truenas", "storage", "nas", "primary"]

  # TrueNAS ISO
  truenas_url      = "https://download.truenas.com/TrueNAS-SCALE-25.10.1/TrueNAS-SCALE-25.10.1.iso"
  truenas_filename = "TrueNAS-SCALE-25.10.1.iso"
  truenas_version  = "25.10.1"

  # Hardware
  cpu_cores        = 8
  memory_mb        = 32768
  boot_disk_size_gb = 32

  # Network
  mac_address = "BC:24:11:2E:D4:03"

  # HBA Passthrough
  enable_hostpci  = true
  hostpci_mapping = "truenas-h330"
}
```

### Optional: Dual Network + Cloud-init

The module also supports a second storage NIC plus cloud-init network configuration
(set `enable_dual_network` and `enable_network_init`, then provide `management_ip`,
`management_gateway`, `storage_ip`, and `dns_server`). See the variables table below.

## Variables

| Variable | Type | Default | Description |
| -------- | ---- | ------- | ----------- |
| `node_name` | string | - | Proxmox node name |
| `vm_id` | number | - | VM ID |
| `vm_name` | string | - | VM name |
| `vm_description` | string | "TrueNAS SCALE..." | VM description |
| `tags` | list(string) | ["truenas"...] | VM tags |
| `truenas_url` | string | - | TrueNAS ISO URL |
| `truenas_filename` | string | - | ISO filename |
| `truenas_version` | string | - | TrueNAS version |
| `cpu_cores` | number | 8 | CPU cores |
| `memory_mb` | number | 32768 | Memory in MB |
| `boot_disk_size_gb` | number | 32 | Boot disk size |
| `mac_address` | string | - | Primary NIC MAC |
| `vlan_id` | number | null | Primary VLAN ID |
| `enable_dual_network` | bool | false | Enable storage NIC |
| `storage_vlan_id` | number | null | Storage VLAN ID |
| `enable_network_init` | bool | false | Enable cloud-init |
| `management_ip` | string | null | Management IP (CIDR) |
| `management_gateway` | string | null | Gateway IP |
| `storage_ip` | string | null | Storage IP (CIDR) |
| `dns_server` | string | null | DNS server IP |
| `enable_hostpci` | bool | false | Enable HBA passthrough |
| `hostpci_mapping` | string | null | PCI device mapping |
| `ignore_changes` | list(string) | [] | Lifecycle ignore list |

## Outputs

| Output | Description |
| ------ | ----------- |
| `vm_id` | TrueNAS VM ID |
| `vm_name` | TrueNAS VM name |
| `node_name` | Proxmox node |
| `mac_address` | Primary MAC address |
| `iso_id` | Downloaded ISO ID |

## Notes

- HBA passthrough must be configured in Proxmox UI after VM creation (Terraform limitation)
- For the primary server, manual network configuration is expected (hence no cloud-init)
- When `enable_network_init` is set, cloud-init handles dual-NIC network configuration
- Lifecycle ignore_changes prevents Terraform from reverting manual HBA additions
