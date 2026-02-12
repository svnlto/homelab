# Network Architecture

> **See also**: [rack-layout.md](rack-layout.md) for physical rack organization, power budget, and hardware specifications.

## Overview

The homelab network uses MikroTik CRS310 switches with RouterOS for L3 inter-VLAN routing and VLAN-aware bridging. The architecture supports both traditional VM/LXC deployments and multiple Kubernetes clusters with proper network isolation.

### Current Setup (Single Router)

**Equipment in use:**
- **CRS310-8G+2S+IN (nevarro)**: Main gateway with NAT/firewall/DHCP + L3 inter-VLAN routing (8x 2.5GbE + 2x 10G SFP+)
- **O2 Homespot**: WAN uplink (modem/bridge mode, 192.168.8.1)
- **Beryl AX (sorgan)**: WiFi-only access point on ether3 (no routing/NAT)
- **Pi-hole**: DNS server for network-wide ad blocking
- **2x Dell PowerEdge servers**: grogu (R630), din (R730xd) with 10GbE X520 NICs

MikroTik is the main gateway at 192.168.0.1, performing NAT to the O2 Homespot WAN uplink. Servers connect directly to router SFP+ ports with all VLANs trunked.

### Future Expansion (Two-Switch Design)

**When CRS310-1G-5S-4S+IN arrives:**
- Dedicated 10GbE aggregation switch for storage fabric
- Reduced router CPU load (L2 switching offloaded to aggregation switch)
- Additional SFP+ ports for expansion (GPU server, future nodes)
- No configuration changes needed (just cable migration)

## Network Topology

### Current (Single Router)

```
                    INTERNET
                        │
                  ┌─────┴──────┐
                  │ O2 Homespot│
                  │192.168.8.1 │
                  │ WAN uplink │
                  └─────┬──────┘
                        │ 192.168.8.2
                        │ ether1 (WAN, standalone)
        ┌───────────────┴────────────────┐
        │   CRS310-8G+2S+IN (Gateway)   │
        │     nevarro-router             │
        │   NAT / Firewall / DHCP        │
        │   L3 Inter-VLAN Routing        │
        │   192.168.0.1 (LAN gateway)    │
        │                                │
        │  8x 2.5GbE      2x 10G SFP+    │
        │  ┌─┬─┬─┬─┬───┐  ┌──────┬────┐  │
        │  │1│2│3│4│5-8│  │ SFP+1│SFP+2│ │
        └──┴─┴─┴─┴─┴───┴──┴──┬───┴─┬───┴─┘
           │ │ │ │           │     │
         WAN Pi Beryl iDRAC grogu  din
              hole AP        X520   X520
                           10GbE  10GbE
                         (trunk)(trunk)
                         All VLANs: 1,10,20,30,31,32
                             │     │
                        ┌────┴─────┴────┐
                        │ R630      R730xd │
                        │ grogu     din    │
                        │ Proxmox   Proxmox│
                        └──────────────────┘
```

### Future (Two-Switch Design)

```
                          ┌──────────────┐
                          │ O2 Homespot  │
                          │ 192.168.8.1  │
                          └──────┬───────┘
                                 │ WAN (ether1)
                  ┌──────────────▼──────────────┐
                  │ CRS310-8G+2S+IN (Router)    │
                  │   nevarro-router            │
                  │   L3 Inter-VLAN Routing     │
                  │   8x 2.5G + 2x SFP+         │
                  └──────────┬──────────────────┘
                             │ 10G DAC trunk
                             │ All VLANs
                  ┌──────────▼──────────────────┐
                  │ CRS310-1G-5S-4S+IN (Switch) │
                  │   nevarro-switch            │
                  │   L2 10GbE Aggregation      │
                  │   4x SFP+ + 5x SFP + 1GbE   │
                  └─┬──────┬──────┬────────────┘
                    │      │      │
                  grogu   din   future
                  X520    X520   GPU
                   10G     10G   10G
```

**Migration benefits:**
- Storage traffic (VLAN 10) stays on dedicated 10GbE fabric
- Inter-VLAN routing still happens on router
- More available ports for expansion
- Lower router CPU usage

## VLAN Architecture

| VLAN | Name               | Subnet          | Gateway      | Purpose                           |
|------|--------------------|-----------------|--------------|-----------------------------------|
| 1    | Management         | 10.10.1.0/24    | 10.10.1.1    | iDRAC, switch management          |
| 10   | Storage            | 10.10.10.0/24   | 10.10.10.1   | 10GbE NFS/iSCSI, TrueNAS          |
| 20   | LAN                | 192.168.0.0/24  | 192.168.0.1  | VMs, clients, WiFi (via Beryl AP) |
| 30   | K8s Shared Services| 10.0.1.0/24     | 10.0.1.1     | Infrastructure cluster            |
| 31   | K8s Apps           | 10.0.2.0/24     | 10.0.2.1     | Production apps cluster           |
| 32   | K8s Test           | 10.0.3.0/24     | 10.0.3.1     | Testing/staging cluster           |
| 33-39| K8s Future         | 10.0.4-10.0/24  | 10.0.X.1     | Reserved for future clusters      |

### VLAN Purposes Explained

**Infrastructure VLANs (1, 10, 20):**
- Traditional network segments for physical infrastructure
- Out-of-band management, storage fabric, general LAN
- Pre-date Kubernetes deployment

**Kubernetes VLANs (30-32):**
- Separate VLAN per cluster for network isolation
- Each cluster has its own IP space and MetalLB pool
- Production apps isolated from test workloads
- Inter-VLAN routing enforced by router firewall rules

**Deployment Strategy:**
- **VLAN 20**: Infrastructure VMs only (TrueNAS, optional utility VMs)
- **VLAN 30-32**: All production workloads on Kubernetes
- **K8s-first approach**: No traditional VM/LXC deployments for applications

## IP Address Allocation

### VLAN 1 - Management (10.10.1.0/24)

| Range          | Purpose                 | Notes                    |
|----------------|-------------------------|--------------------------|
| 10.10.1.1      | Router gateway          | CRS310-8G+2S+IN         |
| 10.10.1.2      | Switch (future)         | CRS310-1G-5S-4S+IN      |
| 10.10.1.10     | grogu iDRAC             | R630 management         |
| 10.10.1.11     | din iDRAC               | R730xd management       |
| 10.10.1.12-50  | Reserved                | Future servers          |
| 10.10.1.100-200| DHCP pool               | Auto-assigned devices   |

### VLAN 10 - Storage (10.10.10.0/24)

| Range           | Purpose                 | Notes                    |
|-----------------|-------------------------|--------------------------|
| 10.10.10.1      | Storage gateway         | Router L3 interface     |
| 10.10.10.2      | Switch mgmt (future)    | Aggregation switch      |
| 10.10.10.10     | grogu storage           | Proxmox X520 interface  |
| 10.10.10.11     | din storage             | Proxmox X520 interface  |
| 10.10.10.12     | Reserved (future GPU)   | Future GPU server       |
| 10.10.10.13     | TrueNAS Primary         | VM on din (192.168.0.13)|
| 10.10.10.14     | TrueNAS Backup          | VM on grogu (192.168.0.14)|
| 10.10.10.20-50  | Reserved VMs            | Future storage services |

### VLAN 20 - LAN (192.168.0.0/24)

| Range            | Purpose                 | Notes                    |
|------------------|-------------------------|--------------------------|
| 192.168.0.1      | Gateway/Router          | MikroTik CRS310 (nevarro) |
| 192.168.0.10     | grogu Proxmox           | Management interface    |
| 192.168.0.11     | din Proxmox             | Management interface    |
| 192.168.0.13     | TrueNAS Primary         | NAS management UI       |
| 192.168.0.14     | TrueNAS Backup          | Backup NAS UI           |
| 192.168.0.53     | Pi-hole                 | DNS/DHCP server         |
| 192.168.0.100-149| DHCP pool               | Dynamic clients (MikroTik DHCP) |
| 192.168.0.150-159| Entertainment           | Apple TV, HomePod, etc. |
| 192.168.0.160-169| Personal devices        | MacBook, iPhone, etc.   |
| 192.168.0.200-250| VMs/Containers          | Reserved for utility VMs |

**Note:** This range is reserved for non-production utility VMs if needed (e.g., development VMs, testing). All production workloads run on Kubernetes (VLANs 30-32).

### VLAN 30 - K8s Shared Services (10.0.1.0/24)

**Cluster Purpose:** Core infrastructure that other clusters depend on

| Range          | Purpose                 | Notes                    |
|----------------|-------------------------|--------------------------|
| 10.0.1.1       | Gateway                 | Router L3 interface     |
| 10.0.1.10      | K8s API VIP             | kube-vip HA endpoint    |
| 10.0.1.11-13   | Control plane nodes     | 3-node HA               |
| 10.0.1.21-29   | Worker nodes            | Up to 9 workers         |
| 10.0.1.100-150 | MetalLB pool            | LoadBalancer services   |

**Services in this cluster:**
- **Monitoring**: SigNoz (centralized observability - metrics, logs, traces)
- **Ingress**: Nginx Ingress Controller (centralized entry point for all clusters)
- **Secrets**: External Secrets Operator, Vault (secret management)
- **GitOps**: ArgoCD, Flux (deployment automation)
- **Cert management**: cert-manager (automatic TLS certificates)
- **Backup**: Velero (cluster backup/restore)

**Why centralized ingress:** Single LoadBalancer IP (e.g., 10.0.1.100) acts as entry point. Ingress inspects Host header and forwards to appropriate backend cluster. This simplifies DNS (all services → one IP) and TLS management (centralized cert-manager).

### VLAN 31 - K8s Apps (10.0.2.0/24)

**Cluster Purpose:** Production user-facing applications

| Range          | Purpose                 | Notes                    |
|----------------|-------------------------|--------------------------|
| 10.0.2.1       | Gateway                 | Router L3 interface     |
| 10.0.2.10      | K8s API VIP             | kube-vip HA endpoint    |
| 10.0.2.11-13   | Control plane nodes     | 3-node HA               |
| 10.0.2.21-29   | Worker nodes            | Up to 9 workers         |
| 10.0.2.100-150 | MetalLB pool            | LoadBalancer services   |

**Services for this cluster:**
- **Media**: Jellyfin, Sonarr, Radarr, Prowlarr, qBittorrent (full arr media automation stack)
- **Photos**: Immich (Google Photos alternative)
- **Files**: Nextcloud (file sync and share)
- **Home automation**: Home Assistant
- **Document management**: Paperless-ngx
- **Password manager**: Vaultwarden (Bitwarden server)

### VLAN 32 - K8s Test (10.0.3.0/24)

**Cluster Purpose:** Testing, staging, and development

| Range          | Purpose                 | Notes                    |
|----------------|-------------------------|--------------------------|
| 10.0.3.1       | Gateway                 | Router L3 interface     |
| 10.0.3.10      | K8s API VIP             | kube-vip HA endpoint    |
| 10.0.3.11-13   | Control plane nodes     | 3-node HA               |
| 10.0.3.21-23   | Worker nodes            | 3 workers (smaller)     |
| 10.0.3.100-150 | MetalLB pool            | LoadBalancer services   |

**Use cases:**
- Staging versions of production apps before promoting to Apps cluster
- CI/CD testing (GitHub Actions, GitLab CI)
- Load testing and performance validation
- Testing new Kubernetes versions before upgrading production clusters
- Experimental deployments without production impact

**Isolation:** Test cluster cannot communicate with Apps cluster (firewall blocked) to prevent accidents.

## Router Configuration (CRS310-8G+2S+IN)

### Port Assignments

**Current (Single Router):**

| Port   | VLAN Mode       | VLAN    | Device            | Cable Type      |
|--------|-----------------|---------|-------------------|-----------------|
| ether1 | WAN (standalone)| —       | O2 Homespot uplink| Cat6A           |
| ether2 | access          | 20      | Pi-hole           | Cat6A           |
| ether3 | access          | 20      | Beryl AX WiFi AP  | Cat6A           |
| ether4 | access          | 1       | din iDRAC         | Cat6A           |
| ether5 | access          | 1       | grogu iDRAC       | Cat6A           |
| ether6-8| access         | 20      | Future devices    | -               |
| sfp+1  | trunk           | 1,10,20,30,31,32 | grogu X520 | 10G DAC/Fiber |
| sfp+2  | trunk           | 1,10,20,30,31,32 | din X520   | 10G DAC/Fiber |

**Future (With Aggregation Switch):**

| Port   | VLAN Mode | VLAN    | Device                  | Cable Type  |
|--------|-----------|---------|-------------------------|-------------|
| ether1-8| (same)  | (same)  | (same)                  | (same)      |
| sfp+1  | trunk     | 1,10,20,30,31,32 | Switch uplink | 10G DAC   |
| sfp+2  | available | -       | Future 10G device       | -           |

### VLAN Interfaces (L3 Gateways)

```routeros
/interface vlan
add interface=bridge1 name=vlan1-mgmt vlan-id=1
add interface=bridge1 name=vlan10-storage vlan-id=10
add interface=bridge1 name=vlan20-lan vlan-id=20
add interface=bridge1 name=vlan30-k8s-shared vlan-id=30
add interface=bridge1 name=vlan31-k8s-apps vlan-id=31
add interface=bridge1 name=vlan32-k8s-test vlan-id=32

/ip address
add address=192.168.8.2/24 interface=ether1 comment="WAN to O2 Homespot"
add address=10.10.1.1/24 interface=vlan1-mgmt comment="Management gateway"
add address=10.10.10.1/24 interface=vlan10-storage comment="Storage gateway"
add address=192.168.0.1/24 interface=vlan20-lan comment="LAN gateway"
add address=10.0.1.1/24 interface=vlan30-k8s-shared comment="K8s Shared Services"
add address=10.0.2.1/24 interface=vlan31-k8s-apps comment="K8s Apps"
add address=10.0.3.1/24 interface=vlan32-k8s-test comment="K8s Test"
```

### Bridge Configuration

```routeros
/interface bridge
add name=bridge1 vlan-filtering=yes

# Add all ports to bridge (ether1 is standalone WAN, not bridged)
/interface bridge port
add bridge=bridge1 interface=ether2 pvid=20
add bridge=bridge1 interface=ether3 pvid=20
add bridge=bridge1 interface=ether4 pvid=1
add bridge=bridge1 interface=ether5 pvid=1
add bridge=bridge1 interface=ether6 pvid=20
add bridge=bridge1 interface=ether7 pvid=20
add bridge=bridge1 interface=ether8 pvid=20
add bridge=bridge1 interface=sfp-sfpplus1 frame-types=admit-only-vlan-tagged
add bridge=bridge1 interface=sfp-sfpplus2 frame-types=admit-only-vlan-tagged

# VLAN membership
/interface bridge vlan
add bridge=bridge1 tagged=bridge1,sfp-sfpplus1,sfp-sfpplus2 untagged=ether4,ether5 vlan-ids=1
add bridge=bridge1 tagged=bridge1,sfp-sfpplus1,sfp-sfpplus2 vlan-ids=10
add bridge=bridge1 tagged=bridge1,sfp-sfpplus1,sfp-sfpplus2 untagged=ether2,ether3,ether6,ether7,ether8 vlan-ids=20
add bridge=bridge1 tagged=bridge1,sfp-sfpplus1,sfp-sfpplus2 vlan-ids=30
add bridge=bridge1 tagged=bridge1,sfp-sfpplus1,sfp-sfpplus2 vlan-ids=31
add bridge=bridge1 tagged=bridge1,sfp-sfpplus1,sfp-sfpplus2 vlan-ids=32
```

## Inter-VLAN Routing & Firewall Rules

### Routing Policy Summary

| From VLAN | To VLAN | Access | Reason |
|-----------|---------|--------|--------|
| 20 (LAN) | 1 (Mgmt) | ✅ Allow | Admin access to iDRAC |
| 20 (LAN) | 10 (Storage) | ✅ Allow | User access to NAS (SMB, NFS) |
| 20 (LAN) | 30 (K8s Shared) | ✅ Allow | Access monitoring, ArgoCD, ingress |
| 20 (LAN) | 31 (K8s Apps) | ✅ Allow | Access Jellyfin, Immich via ingress |
| 20 (LAN) | 32 (K8s Test) | ✅ Allow | Access staging apps |
| 1 (Mgmt) | 10 (Storage) | ❌ Deny | No reason for iDRAC → NAS |
| 1 (Mgmt) | 20 (LAN) | ✅ Allow | iDRAC → LAN if needed |
| 10 (Storage) | 20 (LAN) | ✅ Allow | NAS → LAN for updates |
| 30 (K8s Shared) | 10 (Storage) | ✅ Allow | PV mounts, monitoring TrueNAS |
| 31 (K8s Apps) | 10 (Storage) | ✅ Allow | Media, photos PV mounts |
| 32 (K8s Test) | 10 (Storage) | ✅ Allow | Test data PV mounts |
| 31 (K8s Apps) | 30 (K8s Shared) | ✅ Allow | Metrics, secrets, ingress |
| 32 (K8s Test) | 30 (K8s Shared) | ✅ Allow | Monitoring only |
| 31 (K8s Apps) | 32 (K8s Test) | ❌ Deny | **Prod/test isolation** |
| 32 (K8s Test) | 31 (K8s Apps) | ❌ Deny | **Prod/test isolation** |
| All VLANs | WAN | ✅ Allow | Internet egress via MikroTik NAT |

### Firewall Configuration

```routeros
/ip firewall filter

# Drop invalid packets
add chain=forward action=drop connection-state=invalid comment="Drop invalid"

# Accept established/related connections
add chain=forward action=accept connection-state=established,related comment="Accept established/related"

# === Storage Access ===
add chain=forward action=accept connection-state=new \
    src-address=192.168.0.0/24 dst-address=10.10.10.0/24 \
    comment="LAN → Storage (NAS access)"
add chain=forward action=accept connection-state=new \
    src-address=10.0.1.0/24 dst-address=10.10.10.0/24 \
    comment="K8s Shared → Storage (PVs, monitoring)"
add chain=forward action=accept connection-state=new \
    src-address=10.0.2.0/24 dst-address=10.10.10.0/24 \
    comment="K8s Apps → Storage (media, photos)"
add chain=forward action=accept connection-state=new \
    src-address=10.0.3.0/24 dst-address=10.10.10.0/24 \
    comment="K8s Test → Storage (test data)"
add chain=forward action=accept connection-state=new \
    src-address=10.10.10.0/24 dst-address=192.168.0.0/24 \
    comment="Storage → LAN (updates)"

# === Management Access ===
add chain=forward action=accept connection-state=new \
    src-address=192.168.0.0/24 dst-address=10.10.1.0/24 \
    comment="LAN → Management (iDRAC access)"
add chain=forward action=accept connection-state=new \
    src-address=10.10.1.0/24 dst-address=192.168.0.0/24 \
    comment="Management → LAN"

# === LAN to K8s Access ===
add chain=forward action=accept connection-state=new \
    src-address=192.168.0.0/24 dst-address=10.0.1.0/24 \
    comment="LAN → K8s Shared (monitoring, ingress)"
add chain=forward action=accept connection-state=new \
    src-address=192.168.0.0/24 dst-address=10.0.2.0/24 \
    comment="LAN → K8s Apps (user services)"
add chain=forward action=accept connection-state=new \
    src-address=192.168.0.0/24 dst-address=10.0.3.0/24 \
    comment="LAN → K8s Test (staging access)"

# === Cross-Cluster Communication ===
add chain=forward action=accept connection-state=new \
    src-address=10.0.2.0/24 dst-address=10.0.1.0/24 \
    comment="K8s Apps → K8s Shared (metrics, secrets, ingress)"
add chain=forward action=accept connection-state=new \
    src-address=10.0.3.0/24 dst-address=10.0.1.0/24 \
    comment="K8s Test → K8s Shared (monitoring)"

# === K8s to Internet ===
add chain=forward action=accept connection-state=new \
    src-address=10.0.1.0/24 dst-address=192.168.0.0/24 \
    comment="K8s Shared → LAN (internet)"
add chain=forward action=accept connection-state=new \
    src-address=10.0.2.0/24 dst-address=192.168.0.0/24 \
    comment="K8s Apps → LAN (internet)"
add chain=forward action=accept connection-state=new \
    src-address=10.0.3.0/24 dst-address=192.168.0.0/24 \
    comment="K8s Test → LAN (internet)"

# === Isolation Rules ===
add chain=forward action=drop \
    src-address=10.0.2.0/24 dst-address=10.0.3.0/24 \
    comment="Block K8s Apps → K8s Test (isolation)"
add chain=forward action=drop \
    src-address=10.0.3.0/24 dst-address=10.0.2.0/24 \
    comment="Block K8s Test → K8s Apps (isolation)"
add chain=forward action=drop \
    src-address=10.10.1.0/24 dst-address=10.10.10.0/24 \
    comment="Block Management → Storage"
add chain=forward action=drop \
    src-address=10.10.10.0/24 dst-address=10.10.1.0/24 \
    comment="Block Storage → Management"

# Drop anything else (explicit deny)
add chain=forward action=drop comment="Drop all other inter-VLAN (default deny)"
```

## Proxmox Network Configuration

### Network Interfaces

**Physical interfaces on both grogu and din (Proxmox biosdevname):**
- `nic0`, `nic1`: Intel I350 1GbE (unused, no cable)
- `nic2`: Intel X520 10GbE SFP+ Port 1 (primary, all VLANs trunked)
- `nic3`: Intel X520 10GbE SFP+ Port 2 (spare/future LACP)

### Bridge Configuration

Edit `/etc/network/interfaces` on **both grogu and din**:

```bash
# ============================================================================
# Proxmox Network Configuration
# ============================================================================

auto lo
iface lo inet loopback

# Physical interface (all VLANs trunked)
auto nic2
iface nic2 inet manual
    mtu 9000

# VLAN 10 - Storage (10GbE, Jumbo Frames)
auto vmbr10
iface vmbr10 inet static
    address 10.10.10.10/24    # grogu: .10, din: .11
    bridge-ports nic2.10
    bridge-stp off
    bridge-fd 0
    mtu 9000
    # No gateway - storage VLAN is L2 only for server-to-server

# VLAN 20 - LAN (Proxmox Management + Traditional VMs)
auto vmbr20
iface vmbr20 inet static
    address 192.168.0.10/24   # grogu: .10, din: .11
    gateway 192.168.0.1       # Internet via MikroTik
    bridge-ports nic2.20
    bridge-stp off
    bridge-fd 0
    # This is how you reach Proxmox web UI

# VLAN 30 - K8s Shared Services
auto vmbr30
iface vmbr30 inet manual
    bridge-ports nic2.30
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware no

# VLAN 31 - K8s Apps
auto vmbr31
iface vmbr31 inet manual
    bridge-ports nic2.31
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware no

# VLAN 32 - K8s Test
auto vmbr32
iface vmbr32 inet manual
    bridge-ports nic2.32
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware no
```

Apply changes:
```bash
# Test configuration
ifreload -a -s

# Apply if no errors
ifreload -a
```

### VM/Container Bridge Assignment Examples

**Traditional LXC container (arr-stack on VLAN 20):**
```hcl
resource "proxmox_virtual_environment_container" "arr_stack" {
  node_name = "din"
  vm_id     = 200

  network_interface {
    name   = "eth0"
    bridge = "vmbr20"  # VLAN 20 - LAN
  }

  initialization {
    ip_config {
      ipv4 {
        address = "192.168.0.200/24"
        gateway = "192.168.0.1"
      }
    }
  }
}
```

**Kubernetes node (Apps cluster on VLAN 31):**
```hcl
resource "proxmox_virtual_environment_vm" "k8s_worker" {
  name      = "talos-worker1"
  node_name = "grogu"

  network_device {
    bridge = "vmbr31"  # VLAN 31 - K8s Apps
    model  = "virtio"
  }

  # IP configured via Talos machine config
}
```

## Traffic Flow Examples

### 1. WiFi Client → Jellyfin (via Centralized Ingress)
```
MacBook (192.168.0.160, VLAN 20)
    ↓ WiFi
Beryl AX AP (sorgan)
    ↓ ether3 (untagged VLAN 20)
MikroTik (inter-VLAN routing: VLAN 20 → VLAN 30)
    ↓ sfp+1 trunk (VLAN 30 tagged)
grogu vmbr30
    ↓
K8s Shared Services Ingress (10.0.1.100)
    ↓ East-West traffic: VLAN 30 → VLAN 31 (via router)
K8s Apps Jellyfin pod (10.0.2.x)
```

**Path:** WiFi → Beryl AP → ether3 → MikroTik (20→30) → Ingress → MikroTik (30→31) → Jellyfin

**Why centralized ingress:** Single LoadBalancer IP, unified TLS termination, simplified DNS.

### 2. Jellyfin Pod → TrueNAS NFS (Media Storage)

```
Jellyfin pod (10.0.2.50, VLAN 31)
    ↓ K8s network
Worker node vmbr31
    ↓ nic2.31 (VLAN 31 tagged)
Router SFP+1 (inter-VLAN routing: VLAN 31 → VLAN 10)
    ↓ nic2.10 on din (VLAN 10 tagged)
din vmbr10 (10.10.10.11)
    ↓ VM bridge
TrueNAS VM (10.10.10.13)
    ↓ NFS export
ZFS dataset: bulk/media
```

**Result:** K8s pod accesses TrueNAS via inter-VLAN routing. Democratic-csi uses NFS to provision PersistentVolumes.

### 3. Prometheus (K8s Shared) → TrueNAS Metrics

```
Prometheus pod (10.0.1.25, VLAN 30)
    ↓
Worker node vmbr30
    ↓ nic2.30 (VLAN 30 tagged)
Router (inter-VLAN routing: VLAN 30 → VLAN 10)
    ↓ nic2.10 on din (VLAN 10 tagged)
din vmbr10
    ↓
TrueNAS VM (10.10.10.13:9273)
```

**Result:** Centralized monitoring in Shared Services cluster can scrape all infrastructure (TrueNAS, Proxmox, other clusters).

### 4. K8s Apps → K8s Shared Services (Metrics Push)

```
App pod (10.0.2.45, VLAN 31)
    ↓ Push metrics
Worker node vmbr31
    ↓ nic2.31 (VLAN 31 tagged)
Router (inter-VLAN routing: VLAN 31 → VLAN 30)
    ↓ nic2.30 on grogu (VLAN 30 tagged)
grogu vmbr30
    ↓
Prometheus pod (10.0.1.25, VLAN 30)
```

**Result:** Apps send metrics to centralized Prometheus in Shared Services cluster.

### 5. K8s Node → Internet (Package Updates)

```
Talos worker node (10.0.2.21, VLAN 31)
    ↓ VLAN 31
MikroTik (inter-VLAN routing: VLAN 31 → WAN)
    ↓ NAT (masquerade)
    ↓ ether1 (WAN, 192.168.8.2)
O2 Homespot (192.168.8.1)
    ↓
Internet
```

**Result:** K8s nodes can update packages, pull container images, etc.

### 6. Storage Replication (TrueNAS Primary → Backup)

**Current (Single Router):**
```
TrueNAS Primary (din) - 10.10.10.13
    ↓ VLAN 10
din nic2.10
    ↓ SFP+2 trunk
Router (L2 switching, same VLAN)
    ↓ SFP+1 trunk
grogu nic2.10
    ↓ VLAN 10
TrueNAS Backup (grogu) - 10.10.10.14
```

**All traffic goes through router, but stays on VLAN 10 (L2 switching, not routed).**

**Future (With Aggregation Switch):**
```
TrueNAS Primary (din) - 10.10.10.13
    ↓ SAS to MD1220
din nic2.10
    ↓ SFP+2 trunk (VLAN 10)
Aggregation Switch (L2 switching)
    ↓ SFP+1 trunk (VLAN 10)
grogu nic2.10
    ↓ SAS to MD1200
TrueNAS Backup (grogu) - 10.10.10.14
```

**Traffic stays on aggregation switch (pure L2), router not involved.**

## DNS Configuration (Pi-hole)

### Infrastructure Records

```bash
# Management VLAN (10.10.1.0/24)
10.10.1.1       router.mgmt.home.arpa nevarro-router.mgmt.home.arpa
10.10.1.2       switch.mgmt.home.arpa nevarro-switch.mgmt.home.arpa
10.10.1.10      grogu-idrac.mgmt.home.arpa
10.10.1.11      din-idrac.mgmt.home.arpa

# Storage VLAN (10.10.10.0/24)
10.10.10.1      router-stor.home.arpa
10.10.10.10     grogu-stor.home.arpa
10.10.10.11     din-stor.home.arpa
10.10.10.13     truenas-primary.stor.home.arpa nas-stor.home.arpa
10.10.10.14     truenas-backup.stor.home.arpa backup-stor.home.arpa

# LAN (192.168.0.0/24)
192.168.0.1     router.home.arpa nevarro-router.home.arpa
# Beryl AX (sorgan) - WiFi AP, gets IP via DHCP
192.168.0.10    grogu.home.arpa
192.168.0.11    din.home.arpa
192.168.0.13    truenas.home.arpa nas.home.arpa
192.168.0.14    backup.home.arpa
192.168.0.53    pihole.home.arpa dns.home.arpa
```

### Kubernetes Service Records

**Centralized Ingress (All services via ingress.home.arpa)**
```bash
# All services point to centralized ingress in Shared Services cluster
10.0.1.100      ingress.home.arpa
10.0.1.100      signoz.home.arpa
10.0.1.100      argocd.home.arpa
10.0.1.100      jellyfin.home.arpa
10.0.1.100      immich.home.arpa
10.0.1.100      nextcloud.home.arpa
10.0.1.100      homeassistant.home.arpa

# Control plane VIPs
10.0.1.10       k8s-shared-api.home.arpa
10.0.2.10       k8s-apps-api.home.arpa
10.0.3.10       k8s-test-api.home.arpa
```

**Benefits:** Single LoadBalancer IP, unified TLS termination, simplified DNS management.

## Migration Path

### Current State → Future State

**Phase 1: Current (Single Router)**
- ✅ All infrastructure VLANs operational (1, 10, 20)
- ✅ Traditional VMs/LXC on VLAN 20 (arr-stack, monitoring)
- ✅ TrueNAS deployed with storage access
- ⏳ Add K8s VLANs 30-32 to router
- ⏳ Deploy first K8s cluster (Shared Services on VLAN 30)

**Phase 2: Add Aggregation Switch**
1. Configure CRS310-1G-5S-4S+IN as L2 switch
2. Connect router SFP+1 → switch SFP+4 (10G DAC trunk)
3. Move grogu nic2 → switch SFP+1
4. Move din nic2 → switch SFP+2
5. Test connectivity (no config changes needed on Proxmox/VMs)

**Benefits:**
- Reduced router CPU load
- Dedicated 10GbE storage fabric
- More available ports for expansion

**Phase 3: Kubernetes Deployment (K8s-First)**
1. **Deploy Shared Services cluster (VLAN 30)**
   - SigNoz (observability), ingress, ArgoCD, cert-manager, Vault
2. **Deploy Apps cluster (VLAN 31)**
   - Media stack (Jellyfin, Sonarr, Radarr, Prowlarr, qBittorrent)
   - Photos (Immich), files (Nextcloud), home automation (Home Assistant)
3. **Deploy Test cluster (VLAN 32)**
   - Staging environment, CI/CD, experiments

**Kubernetes Benefits:**
- GitOps (declarative config, version control)
- Automatic updates (ArgoCD, Renovate)
- Better resource utilization (bin packing)
- Self-healing (pod restarts, node failures)
- Easier backups (Velero)
- Storage integration (democratic-csi for TrueNAS)
- Centralized observability (SigNoz across all clusters)

## Performance Considerations

### Current Setup (Single Router)

**All traffic goes through CRS310-8G+2S+IN:**
- Switching capacity: 60 Gbps
- Forwarding rate: 44.64 Mpps
- CPU: 800 MHz (RouterOS on ARM)

**Bottlenecks:**
- Inter-VLAN routing: CPU-based (not hardware offloaded)
- All K8s cross-cluster traffic: Router CPU
- Storage access from K8s: Router CPU (VLAN 30/31/32 → VLAN 10)

**Mitigation:**
- Keep pod-to-pod traffic within same cluster (same VLAN, L2 switching)
- Use centralized ingress to minimize cross-cluster routing
- Storage I/O is read/write intensive, not packet-intensive (should be fine)

### Future Setup (With Aggregation Switch)

**Traffic distribution:**
- Pod-to-pod within cluster: Stay on VLAN (L2 switching on aggregation switch)
- Cross-cluster: Router CPU (unavoidable)
- Storage access: Switch → router → storage VLAN → switch (one routing hop)

**Benefits:**
- Reduced router CPU load (L2 switching offloaded)
- 10GbE storage fabric isolated from compute
- More SFP+ ports for expansion

## Troubleshooting

### Check VLAN Configuration

```routeros
# On router
/interface bridge vlan print
/interface bridge port print
/interface vlan print
/ip address print
/interface bridge host print  # MAC table
```

### Test Inter-VLAN Routing

```bash
# From laptop (VLAN 20)
ping 10.10.1.1      # Router mgmt gateway
ping 10.10.1.10     # grogu iDRAC
ping 10.10.10.13    # TrueNAS storage
ping 10.0.1.1       # K8s Shared gateway
ping 10.0.2.1       # K8s Apps gateway
ping 10.0.3.1       # K8s Test gateway
```

### Check Firewall Rules

```routeros
/ip firewall filter print
/ip firewall connection print where src-address~"10.0"
```

### Verify Proxmox VLAN Interfaces

```bash
# On Proxmox host
ip addr show
bridge link show
cat /proc/net/vlan/config
ip route show

# Test connectivity
ping 10.0.1.1  # K8s Shared gateway
ping 10.10.10.13  # TrueNAS storage
```

### Check K8s Node Connectivity

```bash
# SSH to K8s node
ping 10.0.1.1       # Gateway
ping 10.10.10.13    # TrueNAS (storage access)
ping 192.168.0.1    # Internet gateway
ping 1.1.1.1        # Internet
nslookup google.com 192.168.0.53  # DNS via Pi-hole
```

### Lost Access After Enabling VLAN Filtering

**Option 1: Serial/Console**
```routeros
/interface bridge set bridge1 vlan-filtering=no
```

**Option 2: Factory reset**
```routeros
/system reset-configuration no-defaults=yes
# Then re-apply config
```

## Access URLs

| Service | URL | VLAN | Notes |
|---------|-----|------|-------|
| **Infrastructure** |
| Proxmox grogu | https://192.168.0.10:8006 | 20 | Admin |
| Proxmox din | https://192.168.0.11:8006 | 20 | Admin |
| grogu iDRAC | https://10.10.1.10 | 1 | Out-of-band mgmt |
| din iDRAC | https://10.10.1.11 | 1 | Out-of-band mgmt |
| Router | https://192.168.0.1 | 20 | Winbox/WebFig |
| TrueNAS Primary | https://192.168.0.13 | 20 | NAS management |
| TrueNAS Backup | https://192.168.0.14 | 20 | Backup NAS |
| Pi-hole | http://192.168.0.53/admin | 20 | DNS/DHCP admin |
| **Kubernetes Services (via Ingress)** |
| SigNoz | https://signoz.home.arpa | 30 | Centralized observability |
| ArgoCD | https://argocd.home.arpa | 30 | GitOps |
| Jellyfin | https://jellyfin.home.arpa | 31 | Media streaming |
| Immich | https://immich.home.arpa | 31 | Photo management |
| Nextcloud | https://nextcloud.home.arpa | 31 | File sync/share |
| Home Assistant | https://homeassistant.home.arpa | 31 | Home automation |

## Security Considerations

### VLAN Isolation

**Production ↔ Test isolation enforced:**
- K8s Apps (VLAN 31) ↔ K8s Test (VLAN 32): Blocked by firewall
- Prevents test failures from impacting production
- Prevents production data access from test cluster

**Management ↔ Storage isolation:**
- VLAN 1 (Management) ↔ VLAN 10 (Storage): Blocked
- No reason for iDRAC to access NAS directly
- Reduces attack surface

### Router Hardening

```routeros
# Restrict management access
/ip service
set telnet disabled=yes
set ftp disabled=yes
set www address=10.10.1.0/24,192.168.0.0/24
set winbox address=10.10.1.0/24,192.168.0.0/24
set ssh address=10.10.1.0/24,192.168.0.0/24

# Disable unnecessary services
/ip service
set api disabled=yes
set api-ssl disabled=yes
```

### Future Considerations

- **Network segmentation:** Consider separate VLAN for IoT devices
- **VPN access:** WireGuard for remote management (VLAN 20 access)
- **IDS/IPS:** Suricata on dedicated VM/LXC (mirror ports)
- **Zero Trust:** Implement service mesh (Istio/Linkerd) for mTLS between pods
- **Policy enforcement:** Kubernetes NetworkPolicies for pod-to-pod restrictions

## Summary

### Key Design Principles

1. **VLAN per purpose:** Infrastructure (1,10,20), Kubernetes (30-32), future expansion (33-39)
2. **Separate VLAN per cluster:** Network isolation between shared services, apps, and test
3. **Centralized ingress:** Single entry point (VLAN 30) for all K8s services
4. **Inter-VLAN routing:** L3 switch enforces firewall rules between segments
5. **Migration-friendly:** Traditional VMs/LXC coexist with K8s during transition
6. **Future-proof:** Clear path for adding aggregation switch (no reconfig needed)

### Quick Reference

**Router:** CRS310-8G+2S+IN (nevarro-router) - 192.168.0.1 / 10.10.1.1
**Gateway:** O2 Homespot - 192.168.8.1 (WAN)
**DNS:** Pi-hole - 192.168.0.53
**Proxmox:** grogu (192.168.0.10), din (192.168.0.11)
**TrueNAS:** Primary (192.168.0.13), Backup (192.168.0.14)

**VLANs:** 1 (mgmt), 10 (storage), 20 (LAN), 30 (K8s shared), 31 (K8s apps), 32 (K8s test)

**Current Production:** arr-stack LXC (192.168.0.200) on VLAN 20
**Future Production:** K8s Apps cluster on VLAN 31 (migration target)
