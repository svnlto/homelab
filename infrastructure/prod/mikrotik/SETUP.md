# MikroTik CRS Router Setup Guide

## Phase 3: MikroTik Integration

### Prerequisites

**Hardware:**

- MikroTik CRS series router (Cloud Router Switch)
- Factory default configuration
- Network connectivity for initial setup

**Network:**

- 30-60 minute maintenance window (network will be disrupted)
- Physical access to router or console access
- Current network gateway (Beryl AX) at 192.168.0.1

### Phase 0: Initial Router Setup (Before Terragrunt)

#### Step 1: Physical Connection

```bash
# Connect router to network
# Router will get IP via DHCP or use default 192.168.88.1

# Find router IP
nmap -sn 192.168.0.0/24 | grep -i mikrotik
# Or check Beryl AX DHCP leases
```

#### Step 2: Initial Configuration via WebFig/Winbox

##### Option A: WebFig (Web Interface)

```bash
# Access via browser
open http://192.168.88.1  # Or discovered IP

# Login with default credentials
# Username: admin
# Password: (blank)
```

##### Option B: Winbox (Recommended for macOS via Wine)

```bash
# Download Winbox from mikrotik.com
# Run via Wine or use Web-based Winbox
```

#### Step 3: Create Terraform User

SSH to router:

```bash
ssh admin@192.168.88.1  # Or discovered IP
# Press 'a' for advanced mode

# Create dedicated terraform user
/user add name=terraform group=full password=<STRONG_PASSWORD>

# Verify
/user print
```

#### Step 4: Enable REST API with SSL

```routeros
# Generate self-signed certificate (valid 10 years)
/certificate add name=api-cert common-name=mikrotik-api \
  key-size=2048 days-valid=3650 key-usage=digital-signature,key-encipherment

# Sign the certificate
/certificate sign api-cert

# Wait for certificate to be signed (check with /certificate print)

# Enable HTTPS service with certificate
/ip service set www-ssl certificate=api-cert disabled=no port=443

# Verify HTTPS is enabled
/ip service print detail
```

#### Step 5: Set Static IP

```routeros
# Remove DHCP client (if present)
/ip dhcp-client print
/ip dhcp-client remove [find]

# Set static IP
/ip address add address=192.168.0.2/24 interface=ether1

# Set default gateway (to Beryl AX for internet access)
/ip route add gateway=192.168.0.1

# Set DNS
/ip dns set servers=192.168.0.53  # Pi-hole
```

#### Step 6: Test API Access

From your workstation:

```bash
# Test HTTPS API (ignore SSL warning for self-signed cert)
curl -k -u terraform:<password> https://192.168.0.2/rest/system/resource

# Should return JSON with system info
```

#### Step 7: Add Credentials to .env

```bash
cd ~/Projects/homelab

# Add to .env file
cat >> .env <<EOF
MIKROTIK_USERNAME="terraform"
MIKROTIK_PASSWORD="<STRONG_PASSWORD>"
EOF

# Reload environment
direnv allow
```

### Phase 3: Terragrunt Deployment

**IMPORTANT**: This will reconfigure the router network. Schedule a maintenance window.

#### Step 1: Verify Prerequisites

```bash
# Verify credentials loaded
env | grep MIKROTIK

# Verify Terragrunt available
terragrunt --version

# Verify globals.hcl correct
cat infrastructure/globals.hcl | grep -A 10 "mikrotik ="
```

#### Step 2: Deploy Base Networking (CRITICAL)

```bash
cd infrastructure/mikrotik/base

# Review what will be created
terragrunt plan

# IMPORTANT: Review carefully - this creates VLANs and reconfigures network
# Expected resources:
# - 1 bridge (bridge-vlans)
# - 4 trunk ports (ether1-4, sfp-sfpplus1-2)
# - 6 VLAN interfaces (management, storage, lan, k8s-shared, k8s-apps, k8s-test)
# - 6 IP addresses (gateways)

# Apply during maintenance window
terragrunt apply

# Verify connectivity after apply
ping 192.168.0.2  # Router
ping 192.168.0.10  # Proxmox grogu
ping 192.168.0.53  # Pi-hole
```

**If network breaks:**

```bash
# Option A: SSH to router (if accessible)
ssh admin@192.168.0.2
/system reset-configuration

# Option B: Physical console access
# Connect serial cable, reset to factory defaults
```

#### Step 3: Deploy DHCP Servers

```bash
# Deploy LAN DHCP first
cd infrastructure/mikrotik/dhcp/vlan-20-lan
terragrunt apply

# Test DHCP on a client
# Release/renew DHCP lease, verify IP from 192.168.0.100-149 range

# Deploy K8s VLANs
cd ../vlan-30-k8s-shared && terragrunt apply
cd ../vlan-31-k8s-apps && terragrunt apply
cd ../vlan-32-k8s-test && terragrunt apply
```

#### Step 4: Deploy Firewall Rules

```bash
cd infrastructure/mikrotik/firewall

# CRITICAL: Review firewall rules carefully
terragrunt plan

# Expected:
# - 5 interface lists (zones: wan, lan, management, storage, k8s)
# - 8 interface list members
# - 6 firewall filter rules (established, invalid, lan-to-any, k8s-to-storage, k8s-isolation, default-drop)

terragrunt apply

# Test connectivity
ping 192.168.0.10  # LAN → Management (should work)
ping 10.10.10.13   # LAN → Storage (should work)

# From K8s node (after deployment):
ping 10.10.10.13   # K8s → Storage (should work)
ping 10.0.2.10     # K8s shared → K8s apps (should fail - isolation)
```

#### Step 5: Deploy DNS Forwarding

```bash
cd infrastructure/mikrotik/dns
terragrunt apply

# Verify DNS resolution
nslookup google.com 192.168.0.2  # Router forwards to Pi-hole
```

### Validation

#### Complete System Check

```bash
# All Terragrunt modules should be applied
cd infrastructure/mikrotik
find . -name "terragrunt.hcl" -not -path "*/.terragrunt-cache/*"

# Verify all applied successfully
just tg-list

# Network connectivity
ping 192.168.0.2   # Router
ping 192.168.0.10  # Proxmox
ping 192.168.0.53  # Pi-hole
ping 192.168.0.13  # TrueNAS

# SSH access
ssh admin@192.168.0.2

# DNS resolution
nslookup google.com 192.168.0.53
```

#### MikroTik Router Check

```bash
ssh admin@192.168.0.2

# Check VLANs
/interface vlan print

# Check bridge
/interface bridge print

# Check IP addresses
/ip address print

# Check DHCP servers
/ip dhcp-server print

# Check firewall rules
/ip firewall filter print

# Check DNS
/ip dns print
```

### Rollback Procedures

#### Rollback to Factory Default

```bash
# SSH to router
ssh admin@192.168.0.2

# Reset to factory default
/system reset-configuration no-defaults=yes skip-backup=yes

# Or via console
# System → Reset Configuration → No Default Configuration → Reset
```

#### Rollback Specific Module

```bash
# Destroy specific module (e.g., firewall)
cd infrastructure/mikrotik/firewall
terragrunt destroy

# Or destroy all MikroTik config
cd infrastructure/mikrotik
terragrunt run-all destroy
```

### Troubleshooting

#### Router Not Accessible After Base Apply

1. **Check physical connectivity** - cables, link lights
2. **Try console access** - serial cable
3. **Factory reset** - physical reset button (hold 5+ seconds on boot)
4. **Reconfigure manually** - set IP, enable API

#### DHCP Not Working

```bash
ssh admin@192.168.0.2

# Check DHCP server status
/ip dhcp-server print detail

# Check IP pool
/ip pool print

# Check DHCP leases
/ip dhcp-server lease print

# Check network config
/ip dhcp-server network print
```

#### Firewall Blocking Traffic

```bash
ssh admin@192.168.0.2

# Check firewall counters
/ip firewall filter print stats

# Temporarily disable firewall (TESTING ONLY)
/ip firewall filter disable [find]

# Re-enable
/ip firewall filter enable [find]
```

#### DNS Not Resolving

```bash
ssh admin@192.168.0.2

# Check DNS settings
/ip dns print

# Test DNS from router
/tool fetch url=http://google.com mode=http

# Check DNS cache
/ip dns cache print
```

### Emergency Access

**Console Cable Access:**

1. Connect USB-to-serial cable
2. Use screen/minicom: `screen /dev/tty.usbserial-XXXX 115200`
3. Login as admin
4. Reset or reconfigure

**Physical Reset Button:**

1. Power off router
2. Hold reset button
3. Power on while holding
4. Wait for light pattern indicating reset
5. Release button

**MAC Address Access (Winbox):**

1. Open Winbox
2. Click "Neighbors" tab
3. Connect via MAC address (works even without IP)
4. Reconfigure network settings

### Next Steps After Phase 3

Once MikroTik is deployed and validated:

1. **Update Proxmox bridge configuration** - Point VLANs to new router
2. **Update Pi-hole DHCP** - Disable Beryl AX DHCP, rely on MikroTik
3. **Deploy Kubernetes clusters** - Use new K8s VLANs
4. **Monitor router** - Add to observability stack (Prometheus/Grafana)
5. **Phase 4: Migrate to B2 state backend**

### Useful Commands

```bash
# View all Terragrunt outputs
cd infrastructure/mikrotik
terragrunt run-all output

# Backup current state
just tg-backup

# Show dependency graph
just tg-graph

# Plan all modules
just tg-plan

# Apply specific module
just tg-apply-module mikrotik/base
```
