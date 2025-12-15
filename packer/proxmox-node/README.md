# Proxmox VE Node Image Builder (Apple Silicon)

Builds bootable Proxmox VE node images on Apple Silicon Macs using cloud images instead of running the full Debian installer.

## Why Cloud Images?

Building x86_64 images on ARM64 (Apple Silicon) using the traditional Debian installer approach is extremely slow
(60-90 minutes) due to:

- TCG software emulation (no hardware acceleration)
- UEFI boot complexity
- Preseed timing issues

**This approach**: Uses pre-built Debian cloud images + cloud-init + Ansible

- ⚡ **15-20 minutes** total build time
- ✅ No boot command timing issues
- ✅ Standard cloud workflow
- ✅ Works reliably with TCG emulation

## Quick Start

```bash
# 1. Start the builder VM
cd packer/proxmox-node
vagrant up

# 2. SSH into the VM
vagrant ssh

# 3. Run the build
cd /vagrant
packer init .
packer build .

# 4. Built image will be in output/
ls -lh output/proxmox-node-*/
```

## File Structure

```text
packer/proxmox-node/
├── proxmox-node.pkr.hcl      # Main Packer template
├── variables.pkr.hcl          # Variable definitions
├── cloud-init/
│   ├── user-data              # Cloud-init user configuration
│   └── meta-data              # Cloud-init metadata
├── Vagrantfile                # x86 builder VM
├── output/                    # Built images
└── README.md                  # This file
```

## How It Works

1. **Vagrant** starts an Ubuntu 22.04 ARM64 VM in VMware Fusion
2. **QEMU** (with TCG emulation) runs inside the VM
3. **Packer** downloads a Debian cloud image (.qcow2)
4. **Cloud-init** configures SSH access (no installer needed!)
5. **Ansible** transforms Debian into Proxmox VE
6. **Result**: Bootable Proxmox node image

## Configuration

### Build Variables

Customize the build by editing `variables.pkr.hcl` or passing `-var` flags:

```bash
# Build Proxmox VE 9 (Debian 13 Trixie)
packer build -var 'pve_version=9' .

# Create raw image for bare-metal
packer build -var 'output_format=raw' .

# Watch via VNC (localhost:5900)
packer build -var 'headless=false' .

# Adjust resources
packer build \
  -var 'memory=4096' \
  -var 'cpus=4' \
  -var 'disk_size=64G' .
```

### Available Variables

| Variable | Default | Description |
| -------- | ------- | ----------- |
| `pve_version` | `"8"` | Proxmox VE version (8 or 9) |
| `pve_repository` | `"pve-no-subscription"` | Proxmox repo |
| `output_format` | `"qcow2"` | Output format (qcow2 or raw) |
| `memory` | `2048` | VM memory in MB |
| `cpus` | `2` | Number of CPUs |
| `disk_size` | `"32G"` | Disk size |
| `headless` | `true` | Run without VNC window |
| `install_zfs` | `true` | Install ZFS support |
| `install_cloud_init` | `true` | Keep cloud-init installed |
| `configure_pcie_passthrough` | `true` | Enable IOMMU/PCIe passthrough |

## Deploying the Image

### For VMs (QCOW2)

```bash
# Copy to Proxmox host
scp output/proxmox-node-*/proxmox-node-*.qcow2 root@proxmox:/var/lib/vz/images/

# Import as VM disk
qm importdisk 100 proxmox-node-*.qcow2 local-lvm
```

### For Bare-Metal (RAW)

```bash
# Get the raw image
vagrant ssh -c "cat /vagrant/output/*/proxmox-node-*.raw.gz" > proxmox-node.raw.gz
gunzip proxmox-node.raw.gz

# Write to USB drive or SSD
sudo dd if=proxmox-node.raw of=/dev/sdX bs=4M status=progress conv=fsync

# Boot the physical server from this drive
```

## Build Process Details

### 1. Cloud Image Download

Debian cloud images are downloaded from:

- PVE 8: <https://cloud.debian.org/images/cloud/bookworm/latest/>
- PVE 9: <https://cloud.debian.org/images/cloud/trixie/latest/>

### 2. Cloud-Init Configuration

The `cloud-init/` directory contains:

- **user-data**: Sets root password, enables SSH, grows filesystem
- **meta-data**: Sets hostname/instance-id

Packer creates a virtual CD-ROM with these files (label: `cidata`) that cloud-init reads on first boot.

### 3. Ansible Provisioning

The existing Ansible playbook (`/ansible/playbooks/packer-proxmox-node.yml`) uses these roles:

- `base_system`: System configuration
- `proxmox_install`: Installs Proxmox VE packages
- `proxmox_configure`: Configures Proxmox
- `image_cleanup`: Removes unnecessary packages

## Troubleshooting

### Build Hangs at "Waiting for SSH"

**Symptoms**: Packer stuck for 5+ minutes
**Cause**: Cloud-init not finished
**Solution**:

```bash
# Watch via VNC
packer build -var 'headless=false' .
# Connect to localhost:5900

# Or increase timeout
packer build -var 'ssh_timeout=30m' .
```

### Slow Build Times

**Expected**: First boot takes 3-5 minutes with TCG emulation
**Optimization**:

```bash
# Increase VM resources
export BUILD_VM_MEMORY=12288
export BUILD_VM_CPUS=6
vagrant reload
```

### Cloud-Init Errors

**Check syntax**:

```bash
# Validate user-data
cloud-init schema --config-file cloud-init/user-data
```

### Ansible Connection Failed

**Ensure**: `use_proxy = false` in the ansible provisioner (already configured)

### Download Errors

**Check**: Network connectivity in Vagrant VM

```bash
vagrant ssh
ping cloud.debian.org
```

## Performance Notes

Build times with TCG emulation on Apple Silicon:

| Phase | Time |
| ----- | ---- |
| Download cloud image | 2-3 min |
| First boot | 3-5 min |
| Ansible provisioning | 10-15 min |
| **Total** | **~15-20 min** |

Compare to installer approach: **60-90 minutes**

## Advanced Usage

### Using a Different Base Image

Edit `proxmox-node.pkr.hcl` to use a custom cloud image:

```hcl
locals {
  cloud_image_url = "https://your-mirror/debian-12-custom.qcow2"
  cloud_image_checksum = "sha512:abcd1234..."
}
```

### Two-Stage Builds

Build a base image once, then customize it:

```bash
# Stage 1: Build base Proxmox image
packer build .

# Stage 2: Customize with different Ansible vars
packer build \
  -var 'ansible_extra_vars={"custom_config": "value"}' .
```

### Debugging

Enable verbose Packer logging:

```bash
PACKER_LOG=1 packer build . 2>&1 | tee packer.log
```

## Cleaning Up

```bash
# Remove output images
rm -rf output/

# Stop and remove Vagrant VM
vagrant destroy -f

# Clean Packer cache
rm -rf packer_cache/
```

## Key Differences from Installer Approach

| Aspect | Installer (Old) | Cloud Image (New) |
| ------ | --------------- | ----------------- |
| Build time | 60-90 min | 15-20 min |
| Boot method | Kernel + preseed | Cloud image boot |
| Initial config | Preseed/debconf | cloud-init |
| UEFI support | Complex | Not needed (BIOS) |
| Boot commands | Required, timing-sensitive | None required |
| Base image | ISO installer | Pre-built cloud image |
| Reliability | Flaky on TCG | Very reliable |

## References

- [Debian Cloud Images](https://cloud.debian.org/images/cloud/)
- [Cloud-init Documentation](https://cloudinit.readthedocs.io/)
- [Packer QEMU Builder](https://developer.hashicorp.com/packer/integrations/hashicorp/qemu)
- [Proxmox VE Installation](https://pve.proxmox.com/wiki/Installation)

## Support

This approach is tested on:

- macOS 14+ (Sonoma) with Apple Silicon (M1/M2/M3)
- VMware Fusion 13+
- Vagrant 2.4+
- Packer 1.11+

For issues, check the main repository documentation.
