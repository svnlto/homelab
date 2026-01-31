# NixOS Pi-hole Configuration

This directory contains NixOS configuration for running Pi-hole on Raspberry Pi as a fully declarative, immutable system.

## Why NixOS?

NixOS replaces the Packer + Ansible + Docker approach with a single declarative configuration, providing:

- **True immutability**: Entire OS is reproducible from configuration files
- **Atomic updates**: Transactional changes with automatic rollback capability
- **Simplified builds**: No Vagrant/Docker layers, just Nix cross-compilation from macOS
- **Faster rebuilds**: 2-5 minute incremental builds vs 30-60 minute Packer builds
- **Zero-downtime rollback**: Reboot to previous generation in 30 seconds vs 60+ minute SD reflash

## Architecture

```
nix/
├── flake.nix                  # Main NixOS flake (SD image builder)
├── rpi-pihole/
│   ├── configuration.nix      # System config (network, users, packages)
│   ├── hardware.nix           # Raspberry Pi 4/5 hardware settings
│   └── pihole.nix             # Pi-hole + Unbound services
└── common/
    └── constants.nix          # Shared constants (timezone, versions)
```

## Prerequisites

### Linux Build Environment (macOS only)

**Why needed**: Building NixOS requires executing Linux binaries during the build process. macOS cannot execute Linux ELF binaries, even on ARM Macs.

**Solution**: Use Vagrant + VMware to run a Linux VM for builds.

**Requirements**:

- VMware Fusion (or VirtualBox as alternative)
- Vagrant

**First-time setup**:

```bash
cd ~/Projects/homelab
just nixos-vm-up
```

This creates a Linux VM that can build NixOS images. The `nix/` directory is shared with the VM.

## Quick Start

### 1. Build SD Image

```bash
# From homelab root directory
just nixos-build-pihole
```

First build: 15-20 minutes (downloads all dependencies)
Incremental builds: 2-5 minutes (Nix cache)

### 2. Flash to SD Card

```bash
# Identify SD card (macOS)
diskutil list

# Flash image (with confirmation prompt)
just nixos-flash-pihole /dev/rdiskX
```

**⚠️ Warning**: This will destroy all data on the SD card!

### 3. Boot and SSH

```bash
# Insert SD card into Raspberry Pi and boot
# Wait ~60 seconds for boot

# SSH with 1Password key (Touch ID)
ssh svenlito@192.168.0.53
```

### 4. Verify Services

```bash
# Check Pi-hole service
systemctl status pihole

# Check Docker containers
docker ps

# Test DNS resolution
dig @localhost google.com

# Check metrics endpoint
curl http://localhost:9100/metrics
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

### Pi-hole Version

Pi-hole and Unbound versions defined in `common/constants.nix`:

```nix
{
  piholeVersion = "2025.10.3";
  unboundVersion = "1.24.2";
}
```

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

# Check Docker
systemctl status docker
docker ps
docker logs pihole
```

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
5. **Test DNS** from clients
6. **Total downtime**: ~5 minutes

## Comparison to Packer/Ansible Approach

| Aspect | Packer + Ansible | NixOS |
|--------|-----------------|-------|
| **Build layers** | 3 (macOS → Vagrant → Docker → chroot) | 1 (Nix cross-compile) |
| **Build time** | 30-60 min | 15-20 min (first), 2-5 min (incremental) |
| **Chroot workarounds** | 15+ conditionals | Zero (no chroot) |
| **Immutability** | Partial (containers only) | Complete (OS + containers) |
| **Rollback** | Manual SD reflash (60+ min) | Reboot to generation (30 sec) |
| **OS updates** | apt upgrade (drift risk) | Declarative (no drift) |
| **Configuration** | 338 lines (HCL + YAML + Jinja2) | 205 lines (Nix) |

## Next Steps

After successful NixOS deployment:

1. **Archive Packer/Ansible configs** (move to `_archive/`)
2. **Update CLAUDE.md** to reference NixOS workflow
3. **Add NixOS config to git** for version control
4. **Document lessons learned** in homelab wiki

## References

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [NixOS on ARM](https://nixos.wiki/wiki/NixOS_on_ARM)
- [Raspberry Pi NixOS](https://nixos.wiki/wiki/NixOS_on_ARM/Raspberry_Pi)
- [Nix Flakes](https://nixos.wiki/wiki/Flakes)
