# ARM Builder for Pi-hole

This folder contains everything needed to build the Pi-hole ARM image for Raspberry Pi.

## Why VMware Fusion?

Building ARM images on macOS requires a Linux environment with:

- Loop device support (for mounting disk images)
- Privileged Docker access
- QEMU ARM emulation

Docker Desktop for macOS doesn't support loop devices, so we use VMware Fusion to create an Ubuntu x86_64 VM that can
build ARM images.

## Prerequisites

### 1. Install VMware Fusion

```bash
brew install --cask vmware-fusion
```

### 2. Install Vagrant VMware Plugin

```bash
vagrant plugin install vagrant-vmware-desktop
```

## Quick Start

```bash
# From project root
just arm-vm-up          # Start VMware build VM (first run takes 5-10 min)
just packer-build-pihole # Build Pi-hole image (30-60 min)

# Or from this directory
just vm-up
just build
```

## How It Works

1. **Vagrantfile**: Creates Ubuntu 22.04 VM with VMware Fusion
   - 4GB RAM, 2 CPUs
   - Nested virtualization enabled
   - Installs QEMU, Docker, Packer

2. **Packer**: Uses `mkaczanowski/packer-builder-arm` Docker container
   - Runs with `--privileged` for loop device access
   - Builds ARM image with cloud-init, Pi-hole, Unbound

3. **Output**: Creates `output/rpi-pihole.img` ready to flash to SD card

## Workflow

### Build Image

```bash
just build              # Build image
just images             # List built images
```

### Flash to SD Card

```bash
# Find your SD card
diskutil list

# Flash image (DESTRUCTIVE!)
just flash disk=/dev/rdisk4
```

### Boot Raspberry Pi

1. Insert SD card and power on
2. Wait ~2 minutes for first boot
3. SSH: `ssh ubuntu@192.168.1.2`
4. Pi-hole UI: <http://192.168.1.2/admin> (password: changeme)

## VM Management

```bash
just vm-up              # Start VM
just vm-down            # Stop VM
just vm-ssh             # SSH into VM
just vm-destroy         # Delete VM
just vm-status          # Check VM status
```

## Troubleshooting

### Vagrant fails to start

Check VMware Fusion is installed and licensed:

```bash
brew list --cask vmware-fusion
```

### Build fails with permission errors

The Docker container needs privileged mode for loop devices. This is normal and required.

### Image build is slow

ARM emulation via QEMU is CPU-intensive. Expect 30-60 minutes on modern hardware.

## File Structure

```text
packer/arm-builder/
├── Vagrantfile              # VMware Fusion VM configuration
├── justfile                 # Build commands
├── rpi-pihole.pkr.hcl      # Packer template
├── output/                  # Built images (gitignored)
└── README.md               # This file
```

## Technical Details

### Nested Virtualization

VMware Fusion setting `vhv.enable = TRUE` allows the VM to run QEMU for ARM emulation.

### Loop Devices

The Docker container mounts loop devices to partition and format the disk image:

```bash
losetup -f image.img
kpartx -av /dev/loop0
mkfs.ext4 /dev/mapper/loop0p1
```

This is why we need a full VM instead of Docker Desktop.

## References

- [Packer ARM Builder](https://github.com/mkaczanowski/packer-builder-arm)
- [VMware Fusion Vagrant Provider](https://developer.hashicorp.com/vagrant/docs/providers/vmware)
- [Raspberry Pi Images](https://github.com/solo-io/packer-builder-arm-image)
