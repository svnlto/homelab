# Network Architecture (Two-Switch Design)

> **See also**: [rack-layout.md](rack-layout.md) for physical rack organization, power budget, and hardware specifications.

## Overview

The homelab network uses a two-switch architecture for performance and VLAN separation:

- **CRS310-8G+2S+IN**: L3 Core switch handling inter-VLAN routing (1GbE + 2x SFP+)
- **CRS310-1G-5S-4S+IN**: 10GbE aggregation switch for high-bandwidth storage traffic (4x SFP+ + 5x SFP + 1GbE mgmt)

Switches are interconnected via 10G DAC cable (SFP+ 1 ↔ SFP+ 4) carrying all VLANs as a trunk.

## Physical Topology

```
                    ┌─────────────────┐     ┌───────────────────┐
                    │  M-NET FIBER    │     │   5G O2 HomeSpot  │
                    └────────┬────────┘     └────────┬──────────┘
                             │ Fiber                 │ LAN
                    ┌────────▼────────┐              │
                    │      ONT        │              │
                    └────────┬────────┘              │
                             │ RJ45 WAN              │
                             └───────────┬───────────┘
                                         │
                                ┌────────▼────────┐
                                │    BERYL AX     │
                                │    (sorgan)     │
                                │  Router / NAT   │
                                │  Dual WAN       │
                                │  192.168.0.1    │
                                │      +          │
                                │  WiFi 2.4/5GHz  │
                                └────────┬────────┘
                                         │
         ┌───────────────────────────────┼───────────────────────────────┐
         │                               │                               │
   ┌─────▼─────┐                         │                         ┌─────▼─────┐
   │ Apple TV  │                         │                         │  fennec   │
   │ HomePod   │                         │                         │  iPhone   │
   │ .150-.159 │                         │                         │ .160-.169 │
   └───────────┘                         │                         └───────────┘
                                         │ 1GbE Cat6A
                                         │
                          ┌──────────────▼──────────────┐
                          │   KEYSTONE PATCH PANEL      │
                          │        (24-port, 1U)        │
                          │                             │
                          │  1-6: Cat6A RJ45 (servers)  │
                          │  9-11: LC Fiber (10GbE)     │
                          └──────────────┬──────────────┘
                                         │
                          ┌──────────────▼──────────────┐
                          │ CRS310-8G+2S+IN (L3 Core)   │
                          │   Inter-VLAN Router         │
                          │   8x 2.5G + 2x SFP+         │
                          │   10.10.1.1 (Mgmt)          │
                          └──────────┬──────────────────┘
                                     │
                            10G DAC (1m) - VLAN Trunk
                                     │
              ┌──────────────────────┴──────────────────────────────────────┐
              │                                                              │
   ┌──────────▼─────────────┐                              ┌────────────────▼───────────┐
   │  1GbE Access Layer     │                              │  10GbE Aggregation Layer   │
   │  (VLAN 1, 20)          │                              │  CRS310-1G-5S-4S+IN        │
   │                        │                              │  4x SFP+ + 5x SFP + 1GbE   │
   │  Port 1: sorgan        │                              │  10.10.1.2 (Mgmt)          │
   │  Port 2: grogu iDRAC   │                              │                            │
   │  Port 3: din iDRAC     │                              │  SFP+ 1: grogu X520        │
   │  Port 4: grogu LOM     │                              │  SFP+ 2: din X520          │
   │  Port 5: din LOM       │                              │  SFP+ 3: (future)          │
   │  Port 6: Pi-hole       │                              │  SFP+ 4: Trunk to Core     │
   └────────┬───────────────┘                              └────────────┬───────────────┘
            │                                                           │
            │ 1GbE                                                      │ 10GbE Fiber
            │ VLAN 1, 20                                                │ VLAN 10
            ▼                                                           ▼
   ┌─────────────────────────────────────────────────────────────────────────────────┐
   │                          COMPUTE & STORAGE LAYER                                │
   │                                                                                  │
   │  ┌──────────────┐      ┌──────────────┐      ┌──────────────┐                   │
   │  │ R630 (grogu) │      │ R730xd (din) │      │              │                   │
   │  │ Proxmox VE   │      │ Proxmox VE   │      │              │                   │
   │  │              │      │              │      │              │                   │
   │  │ LOM:         │      │ LOM:         │      │              │                   │
   │  │ 192.168.0.10 │      │ 192.168.0.11 │      │              │                   │
   │  │              │      │              │      │              │                   │
   │  │ X520-DA2:    │      │ X520-DA2:    │      │              │                   │
   │  │ 10.10.10.10  │      │ 10.10.10.11  │      │              │                   │
   │  │              │      │              │      │              │                   │
   │  │ VMs/LXC:     │      │ VMs:         │      │              │                   │
   │  │ - arr-stack  │      │ - TrueNAS    │      │              │                   │
   │  │ - Backup NAS │      │   SCALE      │      │              │                   │
   │  └──────┬───────┘      └──────┬───────┘      └──────────────┘                   │
   │         │ SAS                 │ SAS                                             │
   │  ┌──────▼──────┐       ┌──────▼──────┐                                          │
   │  │  MD1200     │       │  MD1220     │                                          │
   │  │ 12x 3.5" LFF│       │ 24x 2.5" SFF│                                          │
   │  │   Backup    │       │   Primary   │                                          │
   │  └─────────────┘       └─────────────┘                                          │
   │                                                                                  │
   │  Additional: Pi-hole (Raspberry Pi 4B) - 192.168.0.53 (DNS/DHCP)                │
   └──────────────────────────────────────────────────────────────────────────────────┘
```

## Logical Network Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                      INTERNET                                           │
└─────────────────────────────────────────┬───────────────────────────────────────────────┘
                                          │ WAN (Fiber + 4G Failover)
                                          │
┌─────────────────────────────────────────▼───────────────────────────────────────────────┐
│                          BERYL AX (sorgan) - Router                                     │
│                              192.168.0.1                                                │
│                          NAT / Firewall / WiFi AP                                       │
└─────────────────────────────────────────┬───────────────────────────────────────────────┘
                                          │
                                          │ 1GbE Cat6A
                                          │ VLAN 20 (LAN)
                                          │
┌─────────────────────────────────────────▼───────────────────────────────────────────────┐
│                    CRS310-8G+2S+IN (L3 Core / Inter-VLAN Router)                        │
│                                  10.10.1.1                                              │
│                                                                                         │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│  │                         VLAN GATEWAY CONFIGURATION                               │   │
│  │                                                                                  │   │
│  │   VLAN 1 (Mgmt): 10.10.1.1/24      │  iDRAC, switches                           │   │
│  │   VLAN 10 (Storage): 10.10.10.1/24 │  NFS, iSCSI, replication                   │   │
│  │   VLAN 20 (LAN): 192.168.0.254/24  │  VMs, services, clients                    │   │
│  │                                                                                  │   │
│  └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                         │
│  1GbE Ports (2.5G capable):                                                             │
│    Port 1: sorgan (VLAN 20)     │  Port 4: grogu LOM (VLAN 20)                         │
│    Port 2: grogu iDRAC (VLAN 1) │  Port 5: din LOM (VLAN 20)                           │
│    Port 3: din iDRAC (VLAN 1)   │  Port 6: Pi-hole (VLAN 20)                           │
│                                                                                         │
│  10GbE SFP+ Ports:                                                                      │
│    SFP+ 1: 10G DAC trunk to CRS310-1G-5S-4S+IN (all VLANs)                             │
│    SFP+ 2: (future 10G uplink)                                                         │
└─────────────────────────────────────────┬───────────────────────────────────────────────┘
                                          │
                                          │ 10G DAC (1m)
                                          │ VLAN Trunk (1, 10, 20)
                                          │
┌─────────────────────────────────────────▼───────────────────────────────────────────────┐
│                  CRS310-1G-5S-4S+IN (10GbE Aggregation Switch)                          │
│                                10.10.1.2                                                │
│                                                                                         │
│  10GbE SFP+ Ports (VLAN 10 - Storage):                                                  │
│    SFP+ 1: grogu X520-DA2 (10.10.10.10)    │  LC-LC OM4 Fiber 0.3m                     │
│    SFP+ 2: din X520-DA2 (10.10.10.11)      │  LC-LC OM4 Fiber 0.3m                     │
│    SFP+ 3: (reserved - future GPU server)  │  LC-LC OM4 Fiber 1m                       │
│    SFP+ 4: Trunk to CRS310-8G+2S+IN        │  10G DAC 1m (all VLANs)                   │
│                                                                                         │
│  1GbE SFP Ports: (future expansion)                                                     │
└─────────────────────────────────────────┬───────────────────────────────────────────────┘
                                          │
            ┌─────────────────────────────┼─────────────────────────────────┐
            │                             │                                 │
            │ 10GbE Fiber                 │ 10GbE Fiber                     │ 10GbE Fiber
            │ VLAN 10                     │ VLAN 10                         │ VLAN 10
            │                             │                                 │
   ┌────────▼────────┐          ┌─────────▼────────┐            ┌──────────▼──────────┐
   │  DELL R630      │          │  DELL R730xd     │            │   (future)          │
   │   (grogu)       │          │    (din)         │            │  GPU Server         │
   │  Proxmox VE     │          │  Proxmox VE      │            │                     │
   │                 │          │                  │            │  (planned)          │
   │  iDRAC:         │          │  iDRAC:          │            │                     │
   │  10.10.1.10     │          │  10.10.1.11      │            │                     │
   │                 │          │                  │            │                     │
   │  LOM (1GbE):    │          │  LOM (1GbE):     │            └─────────────────────┘
   │  192.168.0.10   │          │  192.168.0.11    │
   │                 │          │                  │
   │  X520 (10GbE):  │          │  X520 (10GbE):   │
   │  10.10.10.10    │          │  10.10.10.11     │
   │                 │          │                  │
   │  ┌───────────┐  │          │  ┌────────────┐  │
   │  │ arr-stack │  │          │  │  TrueNAS   │  │
   │  │ LXC       │  │          │  │  SCALE VM  │  │
   │  │           │  │          │  │            │  │
   │  │ LAN:      │  │          │  │ LAN:       │  │
   │  │.0.200     │  │          │  │.0.13       │  │
   │  │ Stor:     │  │          │  │ Stor:      │  │
   │  │.10.20     │  │          │  │.10.13      │  │
   │  └───────────┘  │          │  └──────┬─────┘  │
   │                 │          │         │ SAS    │
   │  ┌───────────┐  │          │  ┌──────▼─────┐  │
   │  │ Backup    │  │          │  │  MD1220    │  │
   │  │ NAS VM    │  │          │  │ 24x 2.5"   │  │
   │  │           │  │          │  │  Primary   │  │
   │  │ LAN:      │  │          │  └────────────┘  │
   │  │.0.14      │  │          │                  │
   │  │ Stor:     │  │          └──────────────────┘
   │  │.10.14     │  │
   │  └─────┬─────┘  │
   │        │ SAS    │           Pi-hole (Raspberry Pi 4B)
   │  ┌─────▼─────┐  │           • IP: 192.168.0.53
   │  │  MD1200   │  │           • DNS: Port 53
   │  │ 12x 3.5"  │  │           • Admin: Port 80
   │  │  Backup   │  │           • Connected: 1GbE VLAN 20
   │  └───────────┘  │
   │                 │
   └─────────────────┘
```

## IP Address Allocation

### VLAN 1 - Management (10.10.1.0/24)

| IP | Device | Purpose |
|----|--------|---------|
| 10.10.1.1 | CRS310-8G+2S+IN (L3 Core) | Switch management + VLAN gateways |
| 10.10.1.2 | CRS310-1G-5S-4S+IN (10G Agg) | Switch management |
| 10.10.1.10 | grogu (R630) iDRAC | Server management |
| 10.10.1.11 | din (R730xd) iDRAC | Server management |
| 10.10.1.12-50 | (reserved) | Future iDRAC/IPMI |

### VLAN 10 - Storage (10.10.10.0/24)

| IP | Device | Purpose |
|----|-----------|---------|
| 10.10.10.1 | CRS310-8G+2S+IN | Storage VLAN gateway |
| 10.10.10.2 | CRS310-1G-5S-4S+IN | 10G aggregation switch mgmt |
| **Physical Hosts (10GbE)** |
| 10.10.10.10 | grogu X520-DA2 | Proxmox storage interface (10GbE fiber) |
| 10.10.10.11 | din X520-DA2 | Proxmox storage interface (10GbE fiber) |
| 10.10.10.12 | (reserved - future GPU server) | 10GbE storage access |
| **VMs/Storage Services** |
| 10.10.10.13 | TrueNAS SCALE VM (din) | Primary NFS/iSCSI server |
| 10.10.10.14 | TrueNAS Backup VM (grogu) | Backup NFS/iSCSI server |
| 10.10.10.20 | arr-stack (if needed) | NFS client (media) - currently LXC uses VLAN 20 |
| 10.10.10.21-50 | (reserved) | Future VMs needing storage |

### VLAN 20 - LAN (192.168.0.0/24)

| IP | Device | Purpose |
|----|--------|---------|
| **Infrastructure** |
| 192.168.0.1 | Beryl AX (sorgan) | Gateway/Router/WiFi AP |
| 192.168.0.10 | R630 (grogu) LOM | Proxmox management UI |
| 192.168.0.11 | R730xd (din) LOM | Proxmox management UI |
| 192.168.0.12 | (reserved - future GPU server) | 10GbE compute node |
| 192.168.0.13 | TrueNAS SCALE VM (din) | Primary NAS management |
| 192.168.0.14 | TrueNAS Backup VM (grogu) | Backup NAS management |
| 192.168.0.53 | Pi-hole | DNS server |
| **DHCP Pool** |
| 192.168.0.100-149 | DHCP Pool | Dynamic clients |
| **Entertainment (Static)** |
| 192.168.0.150 | Apple TV | Streaming |
| 192.168.0.151 | HomePod | Speaker |
| 192.168.0.152-159 | (reserved) | Future entertainment |
| **Personal Devices (Static)** |
| 192.168.0.160 | MacBook (fennec) | Primary laptop |
| 192.168.0.162 | iPhone | Phone |
| 192.168.0.163-169 | (reserved) | Future personal |
| **VMs/Containers (Static)** |
| 192.168.0.200 | arr-stack (LXC) | Media automation (Sonarr, Radarr, Prowlarr, qBittorrent, Jellyfin) |
| 192.168.0.201 | monitoring-server (VM) | Observability (Grafana, Prometheus, Loki) |
| 192.168.0.202-250 | (reserved) | Future VMs/LXC |

## Switch Configuration

### Switch Interconnect

| From | To | Cable | Purpose |
|------|-----|-------|---------|
| CRS310-8G+2S+IN SFP+ 1 | CRS310-1G-5S-4S+IN SFP+ 4 | 10G DAC (1m) | VLAN trunk (all VLANs) |

### CRS310-1G-5S-4S+IN (10G Aggregation Layer)

**Role**: High-bandwidth storage network aggregation

| Port | Device | VLAN | IP | Cable |
|------|--------|------|-----|-------|
| **10GbE SFP+ Ports** |
| SFP+ 1 | grogu X520-DA2 (Patch 9) | 10 (Storage) | 10.10.10.10 | LC-LC OM4 Fiber 0.3m |
| SFP+ 2 | din X520-DA2 (Patch 10) | 10 (Storage) | 10.10.10.11 | LC-LC OM4 Fiber 0.3m |
| SFP+ 3 | (reserved - future) | — | — | — |
| SFP+ 4 | CRS310-8G+2S+IN trunk | trunk (all VLANs) | — | 10G DAC 1m |
| **1GbE SFP Ports** |
| SFP 1-5 | (future 1G fiber/copper) | — | — | — |
| **Management** |
| GbE | Switch management | 1 (Mgmt) | 10.10.1.2 | — |

### CRS310-8G+2S+IN (L3 Core / Inter-VLAN Router)

**Role**: Layer 3 routing between VLANs, 1GbE access layer

| Port | Device | VLAN | IP | Cable |
|------|--------|------|-----|-------|
| **10GbE SFP+ Ports** |
| SFP+ 1 | CRS310-1G-5S-4S+IN trunk | trunk (all VLANs) | — | 10G DAC 1m |
| SFP+ 2 | (future 10G uplink) | — | — | — |
| **1GbE 2.5G Ports** |
| Port 1 | sorgan (Beryl AX) LAN | 20 (LAN) | 192.168.0.1 | Cat6A Patch 6 (0.3m) |
| Port 2 | grogu iDRAC (Patch 1) | 1 (Mgmt) | 10.10.1.10 | Cat6A 0.3m |
| Port 3 | din iDRAC (Patch 2) | 1 (Mgmt) | 10.10.1.11 | Cat6A 0.3m |
| Port 4 | grogu LOM (Patch 3) | 20 (LAN) | 192.168.0.10 | Cat6A 0.3m |
| Port 5 | din LOM (Patch 4) | 20 (LAN) | 192.168.0.11 | Cat6A 0.3m |
| Port 6 | Pi-hole (Patch 5) | 20 (LAN) | 192.168.0.53 | Cat6A 0.5m |
| Port 7-8 | (available) | — | — | — |
| **Management** |
| Built-in | Switch management | 1 (Mgmt) | 10.10.1.1 | — |

### VLAN Gateways (on CRS310-8G+2S+IN)

The L3 core switch provides inter-VLAN routing:

| VLAN | Interface IP | Purpose |
|------|--------------|---------||  1 | 10.10.1.1/24 | Management gateway |
| 10 | 10.10.10.1/24 | Storage gateway |
| 20 | 192.168.0.254/24 | LAN gateway (fallback, Pi-hole is primary DNS) |

**Note**: Pi-hole (192.168.0.53) provides DNS/DHCP for VLAN 20. Clients use Pi-hole as gateway, which then routes through sorgan (192.168.0.1) for internet access.

## Traffic Flow Examples

### 1. VM Accessing NFS Storage (High Performance - 10GbE)

```
arr-stack container (on grogu)
     │
     ▼
grogu X520-DA2 (10.10.10.10)
     │
     │ LC-LC OM4 Fiber (0.3m)
     │ VLAN 10 (Storage)
     ▼
CRS310-1G-5S-4S+IN SFP+ 1
     │
     │ 10G DAC trunk (1m)
     │ VLAN 10
     ▼
CRS310-8G+2S+IN SFP+ 1 (L3 routing)
     │
     │ 10G DAC trunk (1m)
     │ VLAN 10
     ▼
CRS310-1G-5S-4S+IN SFP+ 4
     │
     │ Direct to SFP+ 2
     ▼
CRS310-1G-5S-4S+IN SFP+ 2
     │
     │ LC-LC OM4 Fiber (0.3m)
     │ VLAN 10
     ▼
din X520-DA2 (10.10.10.11)
     │
     ▼
TrueNAS SCALE VM (10.10.10.13)
     │
     ▼
NFS Share: /mnt/pool/media
```

**Result**: Full 10GbE bandwidth for high-performance storage (streaming, backups, replication)

### 2. Admin Accessing iDRAC (Management - Inter-VLAN Routing)

```
Workstation (WiFi or LAN) - VLAN 20
     │
     ▼
sorgan (192.168.0.1)
     │ 1GbE Cat6A
     ▼
CRS310-8G+2S+IN Port 1 (VLAN 20)
     │
     │ L3 Inter-VLAN Routing (VLAN 20 → VLAN 1)
     │ Routing by CRS310-8G+2S+IN
     ▼
CRS310-8G+2S+IN Port 2 or 3 (VLAN 1)
     │ 1GbE Cat6A
     ▼
iDRAC (10.10.1.10 - grogu or 10.10.1.11 - din)
```

**Result**: L3 switch handles inter-VLAN routing between LAN (VLAN 20) and Management (VLAN 1)

### 3. VM Accessing Internet

```
VM on Proxmox (grogu)
     │ VLAN 20
     ▼
grogu LOM (192.168.0.10)
     │ 1GbE Cat6A
     │ VLAN 20
     ▼
CRS310-8G+2S+IN Port 4
     │ Internal switching
     │ VLAN 20
     ▼
CRS310-8G+2S+IN Port 1
     │ 1GbE Cat6A
     │ VLAN 20
     ▼
sorgan (192.168.0.1)
     │ NAT (Fiber primary, 4G failover)
     │ WAN
     ▼
Internet
```

**Result**: VMs route through Proxmox LOM → L3 Core Switch → Router for internet access

### 4. Replication: Primary → Backup (10GbE Storage Network)

```
TrueNAS SCALE VM (din) - 10.10.10.13
     │
     ▼
din X520-DA2 (10.10.10.11)
     │
     │ LC-LC OM4 Fiber
     │ VLAN 10
     ▼
CRS310-1G-5S-4S+IN SFP+ 2
     │
     │ Internal switching
     ▼
CRS310-1G-5S-4S+IN SFP+ 1
     │
     │ LC-LC OM4 Fiber
     │ VLAN 10
     ▼
grogu X520-DA2 (10.10.10.10)
     │
     ▼
TrueNAS Backup VM (grogu) - 10.10.10.14
     │
     │ SAS SFF-8088
     ▼
Dell MD1200 Disk Shelf (12x 3.5" LFF)
```

**Primary Storage Path**:
- TrueNAS SCALE VM (din) → SAS → Dell MD1220 (24x 2.5" SFF)

**Result**: ZFS replication over dedicated 10GbE storage network, isolated from LAN traffic

### 5. Apple TV Streaming via arr-stack/Jellyfin (Dual-Path: LAN + Storage)

```
CLIENT PATH (1GbE):
Apple TV (192.168.0.150)
     │ WiFi (5GHz)
     ▼
sorgan (192.168.0.1)
     │ 1GbE Cat6A
     ▼
CRS310-8G+2S+IN Port 1
     │ VLAN 20 (LAN)
     ▼
CRS310-8G+2S+IN Port 4
     │ 1GbE Cat6A
     ▼
grogu LOM (192.168.0.10)
     │
     ▼
arr-stack container - LAN Interface (192.168.0.200) ◄─── Serves stream to client

STORAGE PATH (if using dedicated storage VLAN):
arr-stack - Storage Interface (10.10.10.20 - optional)
     │ Mounts NFS
     ▼
grogu X520-DA2 (10.10.10.10)
     │ LC-LC OM4 Fiber
     │ VLAN 10 (Storage)
     ▼
CRS310-1G-5S-4S+IN SFP+ 1
     │ 10G DAC trunk
     ▼
CRS310-8G+2S+IN SFP+ 1 (L3 routing between VLANs)
     │ 10G DAC trunk
     ▼
CRS310-1G-5S-4S+IN SFP+ 4 → SFP+ 2
     │ LC-LC OM4 Fiber
     │ VLAN 10
     ▼
din X520-DA2 (10.10.10.11)
     │
     ▼
TrueNAS SCALE VM (10.10.10.13)
     │ SAS SFF-8088
     ▼
Dell MD1220 (24x 2.5" SFF)
     │
NFS Share: /mnt/pool/media
```

**Result**:
- Client streams via 1GbE LAN (VLAN 20) - sufficient for 4K HDR
- arr-stack/Jellyfin reads media via NFS mount (can use VLAN 10 for dedicated storage if needed)

### 6. fennec Accessing Proxmox UI (Same-VLAN Communication)

```
fennec MacBook (192.168.0.160)
     │ WiFi 5GHz
     │ VLAN 20
     ▼
sorgan Beryl AX (192.168.0.1)
     │ 1GbE Cat6A
     │ VLAN 20
     ▼
CRS310-8G+2S+IN Port 1
     │ Internal switching (no routing needed - same VLAN)
     │ VLAN 20
     ▼
CRS310-8G+2S+IN Port 4
     │ 1GbE Cat6A
     │ VLAN 20
     ▼
grogu LOM (192.168.0.10)
     │
     ▼
Proxmox Web UI (192.168.0.10:8006)
```

**Result**: All devices on VLAN 20 (LAN) can communicate directly without inter-VLAN routing

## Services & Ports

| Service | Host | Port | VLAN | Access |
|---------|------|------|------|--------|
| Beryl AX (sorgan) Admin | 192.168.0.1 | 80 | 20 | LAN |
| Proxmox UI (grogu) | 192.168.0.10 | 8006 | 20 | LAN |
| Proxmox UI (din) | 192.168.0.11 | 8006 | 20 | LAN |
| TrueNAS SCALE VM | 192.168.0.13 | 80/443 | 20 | LAN |
| TrueNAS Backup VM | 192.168.0.14 | 80/443 | 20 | LAN |
| Pi-hole DNS | 192.168.0.53 | 53 | 20 | LAN |
| Pi-hole Admin | 192.168.0.53 | 80 | 20 | LAN |
| arr-stack (Jellyfin) | 192.168.0.200 | 8096 | 20 | LAN |
| Grafana | 192.168.0.201 | 3000 | 20 | LAN |
| NFS Primary | 10.10.10.13 | 2049 | 10 | Storage |
| iSCSI Primary | 10.10.10.13 | 3260 | 10 | Storage |
| NFS Backup | 10.10.10.14 | 2049 | 10 | Storage |
| iSCSI Backup | 10.10.10.14 | 3260 | 10 | Storage |
| iDRAC grogu | 10.10.1.10 | 443 | 1 | Mgmt |
| iDRAC din | 10.10.1.11 | 443 | 1 | Mgmt |

## DNS Configuration (Pi-hole)

```
# Infrastructure
192.168.0.1     sorgan.home.arpa
192.168.0.10    grogu.home.arpa
192.168.0.11    din.home.arpa
192.168.0.13    truenas.home.arpa
192.168.0.14    backup.home.arpa
192.168.0.53    pihole.home.arpa

# Management VLAN
10.10.1.1       switch-core.mgmt.home.arpa
10.10.1.2       switch-agg.mgmt.home.arpa
10.10.1.10      idrac-grogu.mgmt.home.arpa
10.10.1.11      idrac-din.mgmt.home.arpa

# Storage VLAN (Physical Hosts)
10.10.10.10     grogu-stor.home.arpa
10.10.10.11     din-stor.home.arpa

# Storage VLAN (VMs/Services)
10.10.10.13     truenas-stor.home.arpa
10.10.10.14     backup-stor.home.arpa
10.10.10.20     jellyfin-stor.home.arpa

# Entertainment
192.168.0.150   appletv.home.arpa
192.168.0.151   homepod.home.arpa

# Personal Devices
192.168.0.160   fennec.home.arpa
192.168.0.162   iphone.home.arpa

# VMs/Containers
192.168.0.200   arr-stack.home.arpa jellyfin.home.arpa
192.168.0.201   monitoring.home.arpa grafana.home.arpa
```

## Firewall Considerations (sorgan / Beryl AX)

The Beryl AX (sorgan) handles routing and firewall between VLANs:

| From | To | Allow |
|------|-----|-------|
| VLAN 20 (LAN) | VLAN 1 (Mgmt) | Yes (admin access to iDRAC) |
| VLAN 20 (LAN) | VLAN 10 (Storage) | No (VMs access storage, not clients) |
| VLAN 1 (Mgmt) | VLAN 20 (LAN) | Limited (monitoring only) |
| VLAN 10 (Storage) | Any | No (isolated) |

## WiFi Configuration (sorgan / Beryl AX)

| Setting | Value |
|---------|-------|
| Mode | Router (dual WAN failover) |
| WAN1 | RJ45 (ONT / Fiber) |
| WAN2 | USB (4G Dongle) |
| Failover | Enabled |
| SSID | HomeNetwork (or your choice) |
| Security | WPA3/WPA2 |
| 2.4GHz | Enabled (IoT, range) |
| 5GHz | Enabled (speed) |
| Band Steering | Enabled |
| Channel Width | 2.4GHz: 20MHz, 5GHz: 80MHz |
| DHCP Server | Disabled (Pi-hole handles this) |
| DNS | 192.168.0.53 (Pi-hole) |

## WiFi Client Summary

| Device | IP | MAC Reservation | Notes |
|--------|-----|-----------------|-------|
| **Entertainment** |
| Apple TV | 192.168.0.150 | Yes | 5GHz preferred |
| HomePod | 192.168.0.151 | Yes | 5GHz |
| **Personal** |
| MacBook (fennec) | 192.168.0.160 | Yes | Primary workstation |
| iPhone | 192.168.0.162 | Yes | |
