# NixOS Pi-hole Configuration

This directory contains NixOS configuration for running Pi-hole on Raspberry Pi as a fully declarative, immutable system.

## Why NixOS?

NixOS replaces the Packer + Ansible + Docker approach with a single declarative configuration, providing:

- **True immutability**: Entire OS is reproducible from configuration files
- **Atomic updates**: Transactional changes with automatic rollback capability
- **Simplified builds**: Single-layer Vagrant VM build (vs 3-layer Packer + Docker + chroot)
- **Faster rebuilds**: 2-5 minute incremental builds vs 30-60 minute Packer builds
- **Zero-downtime rollback**: Reboot to previous generation in 30 seconds vs 60+ minute SD reflash

## Architecture

```text
nix/
├── Vagrantfile                # Linux VM for building (macOS limitation)
├── flake.nix                  # Main NixOS flake (SD image builder)
├── rpi-pihole/
│   ├── configuration.nix      # System config (network, users, packages)
│   ├── hardware.nix           # Raspberry Pi 4/5 hardware settings
│   └── pihole.nix             # Pi-hole + Unbound services
└── common/
    └── constants.nix          # Shared constants (timezone, versions)
```

## Prerequisites

### Linux Build Environment (Required for macOS)

**Why needed**: Building NixOS requires executing Linux binaries during the build process. macOS cannot
execute Linux ELF binaries, even on ARM Macs.

**Solution**: Use Vagrant + VMware to run an Ubuntu VM for builds.

**Requirements**:

- VMware Fusion
- Vagrant
- ~15GB free disk space (for VM and build artifacts)

**First-time setup**:

```bash
cd ~/Projects/homelab
just nixos-vm-up
```

This creates an Ubuntu 22.04 VM (8GB RAM, 60GB disk) that builds NixOS images. The `nix/` directory is shared
with the VM using VMware's native shared folders.

**VM Management**:

```bash
# Start VM
just nixos-vm-up

# Stop VM
just nixos-vm-down

# Destroy VM (to recreate from scratch)
just nixos-vm-destroy

# SSH into VM
just nixos-vm-ssh
```

## Quick Start

### 1. Build SD Image

```bash
# From homelab root directory
just nixos-build-pihole
```

**Build times**:

- First build: 15-20 minutes (downloads NixOS packages, Docker images)
- Incremental builds: 2-5 minutes (Nix cache)

**Output**: `nix/pihole-nixos.img` (~4GB)

### 2. Flash to SD Card

```bash
# Identify SD card (macOS)
diskutil list

# Flash image (with confirmation prompt)
just nixos-flash-pihole /dev/diskX
```

**⚠️ Warning**: This will destroy all data on the SD card!

**Expected output**:

```text
Flashing nix/pihole-nixos.img to /dev/disk4
⚠️  This will DESTROY all data on /dev/disk4!
Continue? (y/N) y
Unmounting /dev/disk4...
Flashing image (this will take ~5 minutes)...
4294967296 bytes transferred in 297.123 secs
✓ Done! SD card ejected.
```

### 3. Boot and SSH

```bash
# Insert SD card into Raspberry Pi and boot
# Wait ~60 seconds for boot

# SSH with 1Password key (Touch ID)
ssh svenlito@192.168.0.53
```

### 4. Set Pi-hole Admin Password

**Important**: The Pi-hole web password must be set manually after first boot.

```bash
# SSH into Pi
ssh svenlito@192.168.0.53

# Set password
docker exec pihole pihole setpassword 'your-password-here'
```

Or use the default from the config (for testing only):

```bash
docker exec pihole pihole setpassword 'changeme'
```

### 5. Verify Services

```bash
# Check Pi-hole service
systemctl status pihole

# Check Docker containers (should show pihole + unbound)
docker ps

# Test DNS resolution
dig @localhost google.com

# Check metrics endpoint
curl http://localhost:9100/metrics

# Access web interface
# http://192.168.0.53/admin
```

**Expected output from `docker ps`**:

```text
CONTAINER ID   IMAGE                       COMMAND         STATUS
43d258627be9   pihole/pihole:2025.03.0     "start.sh"      Up (healthy)
f0ebb8fa8197   mvance/unbound-rpi:latest   "/unbound.sh"   Up (healthy)
```

## Configuration

### Network Settings

Default IP: `192.168.0.53` (configured in `rpi-pihole/configuration.nix`)

To change IP for testing (e.g., run in parallel with existing Pi-hole):

```nix
# rpi-pihole/configuration.nix
networking.interfaces.eth0.ipv4.addresses = [{
  address = "192.168.0.54";  # Changed from .53
  prefixLength = 24;
}];
```

### Docker Image Versions

Pi-hole and Unbound versions defined in `common/constants.nix`:

```nix
{
  piholeVersion = "2025.03.0";
  unboundImage = "mvance/unbound-rpi:latest";  # ARM image required
}
```

**Important**: Must use `mvance/unbound-rpi` (ARM) not `mvance/unbound` (x86).

Update versions here, then rebuild with `just nixos-build-pihole`.

### SSH Keys

SSH public key configured in `rpi-pihole/configuration.nix`:

```nix
users.users.svenlito = {
  openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3... (from 1Password)"
  ];
};
```

## System Updates

### On the Raspberry Pi

NixOS supports atomic updates with instant rollback:

```bash
# SSH into Pi
ssh svenlito@192.168.0.53

# Update system
sudo nixos-rebuild switch --flake /etc/nixos#rpi-pihole

# List all generations
nix-env --list-generations --profile /nix/var/nix/profiles/system

# Rollback to previous generation
sudo nixos-rebuild switch --rollback
```

### From macOS (Rebuild Image)

```bash
# Update flake lock (get latest NixOS packages)
just nixos-update-pihole

# Rebuild SD image
just nixos-build-pihole

# Flash to SD card
just nixos-flash-pihole /dev/rdiskX
```

## Rollback Procedure

### Method 1: Command Line (30 seconds)

```bash
ssh svenlito@192.168.0.53
sudo nixos-rebuild switch --rollback
```

### Method 2: Boot Menu (60 seconds)

1. Reboot Pi: `sudo reboot`
2. Press any key during boot to enter menu
3. Select previous generation (e.g., "NixOS - Configuration 2")
4. System boots to previous working state

### Method 3: SD Card Swap (2 minutes)

If NixOS is completely broken:

1. Power off Raspberry Pi
2. Remove NixOS SD card
3. Insert backup Debian SD card
4. Power on (back to working Debian Pi-hole)

## Automatic Updates

NixOS is configured for automatic daily updates:

```nix
system.autoUpgrade = {
  enable = true;
  allowReboot = false;  # Manual reboot required
  dates = "daily";
  flake = "/etc/nixos";
};
```

Check update status:

```bash
systemctl status nixos-upgrade.service
journalctl -u nixos-upgrade.service
```

## Monitoring

Prometheus node exporter runs on port 9100:

```bash
# Check metrics
curl http://192.168.0.53:9100/metrics

# Add to Prometheus scrape config
- job_name: 'pihole'
  static_configs:
    - targets: ['192.168.0.53:9100']
```

## Troubleshooting

### Build Errors

#### "No space left on device"

**Most common cause**: Low disk space on **host macOS** (not VM)

The `/vagrant` shared folder uses your Mac's disk. Check host disk space:

```bash
df -h /
```

If your Mac has < 10GB free, you'll see this error. The build now uses VM's `/tmp` (60GB available) to avoid this issue.

**If the VM runs out of space**, run garbage collection:

```bash
# Clean up Nix store and build artifacts
just nixos-clean

# Or manually in VM
just nixos-vm-ssh
rm -rf /tmp/nix-* /tmp/tmp.*
nix-collect-garbage -d
```

**If the VM disk is truly full** (rare), expand the filesystem:

```bash
# SSH into VM
just nixos-vm-ssh

# Expand LVM volume
sudo pvresize /dev/sda3
sudo lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv
sudo resize2fs /dev/ubuntu-vg/ubuntu-lv

# Verify space
df -h /
```

#### Configuration validation

```bash
# Validate configuration syntax
just nixos-check-pihole

# Check flake evaluation
cd nix && nix flake show
```

### Boot Issues

**NixOS won't boot**:

- Check serial console: `screen /dev/tty.usbserial 115200`
- Try previous generation from boot menu
- Swap to backup SD card

**Network not working**:

- Verify static IP in `configuration.nix`
- Check gateway and DNS settings
- Verify firewall ports (22, 53, 80, 9100)

### Service Issues

```bash
# Check all services
systemctl status

# Check Pi-hole logs
journalctl -u pihole -f

# Check Docker containers
systemctl status docker
docker ps
docker logs pihole
docker logs unbound
```

**Common issues**:

- **Unbound restarting**: Wrong architecture (must use `mvance/unbound-rpi` for ARM)
- **Pi-hole password wrong**: Password must be set manually with `pihole setpassword`
- **DNS not resolving**: Check unbound is healthy (`docker ps`)

## Migration from Debian/Ubuntu

### Parallel Testing (Recommended)

1. **Deploy on spare Pi** (IP: 192.168.0.54)
2. **Run in parallel** for 1-2 weeks
3. **Validate stability** before migration
4. **Swap to primary** (change IP to 192.168.0.53)
5. **Keep Debian SD** as emergency backup

### Direct Migration (Faster but Riskier)

1. **Build NixOS image** with IP 192.168.0.53
2. **Power off Debian Pi**
3. **Swap SD cards** (keep Debian card safe)
4. **Boot NixOS Pi**
5. **Set admin password**: `docker exec pihole pihole setpassword 'password'`
6. **Test DNS** from clients
7. **Total downtime**: ~5 minutes

## Comparison to Packer/Ansible Approach

| Aspect | Packer + Ansible | NixOS |
| ------ | ---------------- | ----- |
| **Build environment** | macOS → Vagrant → Docker → ARM chroot | macOS → Vagrant → Nix |
| **Build time** | 30-60 min | 15-20 min (first), 2-5 min (incremental) |
| **Chroot workarounds** | 15+ conditionals | Zero (no chroot) |
| **Immutability** | Partial (containers only) | Complete (OS + containers) |
| **Rollback** | Manual SD reflash (60+ min) | Reboot to generation (30 sec) |
| **OS updates** | apt upgrade (drift risk) | Declarative (no drift) |
| **Configuration** | 338 lines (HCL + YAML + Jinja2) | 245 lines (Nix) |

## VM Architecture Details

**Why Vagrant is still needed**:

macOS (even on Apple Silicon) cannot execute Linux ELF binaries. NixOS builds require running Linux
executables during the build process, so a Linux VM is mandatory.

**What changed from Packer approach**:

- ❌ Removed: Docker layer inside VM (Packer used mkaczanowski/packer-builder-arm)
- ❌ Removed: ARM chroot environment with 15+ conditional workarounds
- ❌ Removed: Loop device mounting complexity
- ✅ Simpler: Direct Nix build in Ubuntu VM
- ✅ Faster: Nix caching vs full rebuilds
- ✅ Cleaner: VMware native shared folders vs rsync

## Implementation Notes

### First Boot Process

1. **NixOS boots** (~45 seconds)
2. **Network configured** (static IP 192.168.0.53)
3. **Docker starts** (~15 seconds)
4. **Pi-hole service starts** and pulls Docker images (~60 seconds first boot)
5. **Services ready** (total ~2 minutes)

### Password Management

Pi-hole's `WEBPASSWORD` environment variable only applies on first container creation. If the container is
recreated from existing volumes, the old password persists.

**Solution**: Always set password explicitly after deployment:

```bash
docker exec pihole pihole setpassword 'your-password'
```

### ARM vs x86 Images

Raspberry Pi 4/5 uses `aarch64` (ARM64v8). Always verify Docker images support ARM:

- ✅ `pihole/pihole:2025.03.0` - Multi-arch (supports ARM)
- ✅ `mvance/unbound-rpi:latest` - ARM-specific
- ❌ `mvance/unbound:1.22.0` - x86 only (will fail with "exec format error")

## Next Steps

After successful NixOS deployment:

1. ✅ **Phase 1 complete**: NixOS image built and tested
2. **Phase 2**: Run in parallel with existing Pi-hole (1-2 weeks)
3. **Phase 3**: Migrate primary Pi-hole to NixOS
4. **Future**: Archive Packer/Ansible configs to `_archive/`

## References

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [NixOS on ARM](https://nixos.wiki/wiki/NixOS_on_ARM)
- [Raspberry Pi NixOS](https://nixos.wiki/wiki/NixOS_on_ARM/Raspberry_Pi)
- [Nix Flakes](https://nixos.wiki/wiki/Flakes)
- [Pi-hole Docker](https://github.com/pi-hole/docker-pi-hole)
- [Unbound Docker (ARM)](https://hub.docker.com/r/mvance/unbound-rpi)
