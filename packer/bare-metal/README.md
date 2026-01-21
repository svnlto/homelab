# Proxmox VE Bare-Metal Image Builder

Builds bootable Proxmox VE installation images for Dell PowerEdge servers (r630, r730xd).

**Optimized for Apple Silicon Macs** - Uses cloud images instead of Debian installer for
faster build times (15-20 min vs 60-90 min).

## Use Case

Install Proxmox VE on physical servers by:

1. Building bootable disk image on Apple Silicon Mac
2. Flashing image to USB drive or SSD
3. Booting Dell server from disk
4. Proxmox VE ready immediately (no manual installation)

## ⚠️ NOT for VM Templates

**This builds bootable Proxmox VE images for bare metal.**

If you want to create VM templates inside Proxmox for rapid cloning, use:
`packer/proxmox-templates/` instead.

## Quick Start

```bash
# From project root
just bare-metal-vm-up              # Start build VM (one time)
just packer-build-bare-metal       # Build image (15-20 min)
just bare-metal-flash /dev/rdiskX  # Flash to USB/SSD
```

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

## Build Options

### Default Build (recommended)

- Proxmox VE 9
- ZFS support enabled
- PCIe passthrough configured
- Cloud-init enabled
- Output: raw disk image (.raw.gz)

### Custom Build

```bash
cd packer/bare-metal
vagrant ssh -c "cd /vagrant && packer build \
  -var 'pve_version=8' \
  -var 'install_zfs=false' \
  -var 'install_ceph=true' \
  ."
```

### Available Variables

| Variable | Default | Description |
| -------- | ------- | ----------- |
| `pve_version` | `"9"` | Proxmox VE version (8 or 9) |
| `pve_repository` | `"pve-no-subscription"` | Proxmox repo |
| `output_format` | `"raw"` | Output format (raw for bare-metal, qcow2 for testing) |
| `memory` | `4096` | VM memory in MB |
| `cpus` | `4` | Number of CPUs |
| `disk_size` | `"32G"` | Disk size |
| `headless` | `true` | Run without VNC window |
| `install_zfs` | `true` | Install ZFS support |
| `install_ceph` | `false` | Install Ceph cluster support (adds 40-60 min) |
| `install_cloud_init` | `true` | Keep cloud-init installed |
| `configure_pcie_passthrough` | `true` | Enable IOMMU/PCIe passthrough |

## Manual Build Steps

```bash
# 1. Start the builder VM
cd packer/bare-metal
vagrant up

# 2. SSH into the VM
vagrant ssh

# 3. Run the build
cd /vagrant
packer init .
packer build -var 'output_format=raw' .

# 4. Built image will be in output/
ls -lh output/proxmox-node-*/
```

## Deploying the Image

### For Bare-Metal (RAW)

```bash
# Using justfile (easiest)
just bare-metal-flash /dev/rdiskX

# Or manually
IMAGE=$(ls -t packer/bare-metal/output/*/*.raw.gz | head -1)
gunzip -c "$IMAGE" > proxmox-node.raw
sudo dd if=proxmox-node.raw of=/dev/rdiskX bs=4M status=progress conv=fsync

# Boot the physical server from this drive
```

### For Testing in VM (QCOW2)

```bash
# Build with qcow2 format
cd packer/bare-metal
vagrant ssh -c "cd /vagrant && packer build -var 'output_format=qcow2' ."

# Copy to Proxmox host
scp output/proxmox-node-*/proxmox-node-*.qcow2 root@proxmox:/var/lib/vz/images/

# Import as VM disk
qm importdisk 100 proxmox-node-*.qcow2 local-lvm
```

## How It Works

1. **Vagrant** starts an Ubuntu 22.04 ARM64 VM in VMware Fusion
2. **QEMU** (with TCG emulation) runs inside the VM
3. **Packer** downloads a Debian cloud image (.qcow2)
4. **Cloud-init** configures SSH access (no installer needed!)
5. **Ansible** transforms Debian into Proxmox VE
6. **Result**: Bootable Proxmox node image

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

The Ansible playbook (`/ansible/playbooks/packer-proxmox-node.yml`) uses these roles:

- `base_system`: System configuration
- `proxmox_install`: Installs Proxmox VE packages
- `proxmox_configure`: Configures Proxmox
- `image_cleanup`: Removes unnecessary packages

## Performance Notes

Build times with TCG emulation on Apple Silicon:

| Phase | Time |
| ----- | ---- |
| Download cloud image | 2-3 min |
| First boot | 3-5 min |
| Ansible provisioning | 10-15 min |
| **Total** | **~15-20 min** |

Compare to installer approach: **60-90 minutes**

## Troubleshooting

### Build Hangs at "Waiting for SSH"

**Symptoms**: Packer stuck for 5+ minutes
**Cause**: Cloud-init not finished
**Solution**:

```bash
# Watch via VNC
vagrant ssh -c "cd /vagrant && packer build -var 'headless=false' ."
# Connect to localhost:5900

# Or increase timeout
vagrant ssh -c "cd /vagrant && packer build -var 'ssh_timeout=30m' ."
```

### Slow Build Times

**Expected**: First boot takes 3-5 minutes with TCG emulation
**Optimization**:

```bash
# Increase VM resources (edit Vagrantfile)
# Then reload:
cd packer/bare-metal
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

## File Structure

```text
packer/bare-metal/
├── proxmox-node.pkr.hcl      # Main Packer template
├── variables.pkr.hcl          # Variable definitions
├── cloud-init/
│   ├── user-data              # Cloud-init user configuration
│   └── meta-data              # Cloud-init metadata
├── Vagrantfile                # x86 builder VM
├── output/                    # Built images
└── README.md                  # This file
```

## Cleaning Up

```bash
# Remove output images
just clean

# Stop and remove Vagrant VM
just bare-metal-vm-destroy

# Or manually
cd packer/bare-metal
rm -rf output/
vagrant destroy -f
rm -rf packer_cache/
```

## Key Differences from Installer Approach

| Aspect | Installer (Archived) | Cloud Image (Current) |
| ------ | -------------------- | --------------------- |
| Build time | 60-90 min | 15-20 min |
| Boot method | Kernel + preseed | Cloud image boot |
| Initial config | Preseed/debconf | cloud-init |
| UEFI support | Complex | Automatic |
| Boot commands | Required, timing-sensitive | None required |
| Base image | ISO installer | Pre-built cloud image |
| Reliability | Flaky on TCG | Very reliable |

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
just packer-build-bare-metal

# Stage 2: Customize with different Ansible vars
cd packer/bare-metal
vagrant ssh -c "cd /vagrant && packer build \
  -var 'ansible_extra_vars={\"custom_config\": \"value\"}' ."
```

### Debugging

Enable verbose Packer logging:

```bash
cd packer/bare-metal
vagrant ssh -c "cd /vagrant && PACKER_LOG=1 packer build . 2>&1 | tee packer.log"
```

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
