# Physical Rack Layout (18U Acoustic Cabinet)

> **See also**: [network-layout.md](network-layout.md) for detailed network topology, VLAN configuration, IP allocations, and traffic flows.

```
┌──────────────────────────────────────────────────────────────────────────┐
│                          19" RACK - FRONT VIEW                           │
│                       (18U Acoustic Cabinet, 1000mm deep)                │
│                         19" Tech / Intellinet                            │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │ 1U   KEYSTONE PATCH PANEL (24-port)                                │  │
│  │      ┌───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┐             │  │
│  │      │ 1 │ 2 │ 3 │ 4 │ 5 │ 6 │ 7 │ 8 │ 9 │10 │11 │12 │             │  │
│  │      │iDR│iDR│LOM│LOM│Pi │WAN│   │   │LC │LC │LC │   │             │  │
│  │      │gro│din│gro│din│   │   │ — │ — │gro│din│GPU│ — │             │  │
│  │      └───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┘             │  │
│  │      ┌───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┐             │  │
│  │      │13 │14 │15 │16 │17 │18 │19 │20 │21 │22 │23 │24 │             │  │
│  │      │   │   │   │   │   │   │   │   │   │   │   │   │             │  │
│  │      └───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┘             │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │ 1U   NETWORK SHELF                                                 │  │
│  │      ┌────────────────────┐  ┌────────────────────┐                │  │
│  │      │     BERYL AX       │  │      Pi-hole       │                │  │
│  │      │     (sorgan)       │  │      (Pi 4B)       │                │  │
│  │      │   WAN Gateway      │  │    DNS / DHCP      │                │  │
│  │      └────────────────────┘  └────────────────────┘                │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │ 1U   NEATPATCH CABLE MANAGEMENT                                    │  │
│  │      ┌──────────────────────────────────────────────────────────┐  │  │
│  │      │ ≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋   │  │  │
│  │      │ Patch cable slack management between panel and switches  │  │  │
│  │      └──────────────────────────────────────────────────────────┘  │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │ 1U   MIKROTIK SWITCH SHELF                                         │  │
│  │      ┌──────────────────────────┐  ┌──────────────────────────┐    │  │
│  │      │   CRS310-8G+2S+IN        │  │   CRS310-1G-5S-4S+IN     │    │  │
│  │      │   L3 Core / Inter-VLAN   │  │   10G Aggregation        │    │  │
│  │      │   ○○○○○○○○ ◇◇            │  │   ○ ◇◇◇◇◇ ◆◆◆◆           │    │  │
│  │      │   8x2.5G    2xSFP+       │  │   1G 5xSFP  4xSFP+       │    │  │
│  │      └──────────────────────────┘  └──────────────────────────┘    │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │ 1U   BRUSH PANEL (cable pass-through)                              │  │
│  │      ════════════════════════════════════════════════════════      │  │
│  │      Fiber/copper pass-through from compute section below          │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │ 4U   BLANK/VENTED PANELS                                           │  │
│  │      ┌──────────────────────────────────────────────────────────┐  │  │
│  │      │ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │  │  │
│  │      │                   (future expansion)                     │  │  │
│  │      │ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │  │  │
│  │      └──────────────────────────────────────────────────────────┘  │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│  ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐  │
│            ▲ HEAD END (9U) ───────────── COMPUTE (9U) ▼               │
│  └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘  │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │ 1U   DELL R630 (grogu) - PROXMOX VE                                │  │
│  │      ┌──────────────────────────────────────────────────────────┐  │  │
│  │      │ LOM 1GbE        → Patch 3 → CRS310-8G+2S+IN Port 4       │  │  │
│  │      │ iDRAC           → Patch 1 → CRS310-8G+2S+IN Port 2       │  │  │
│  │      │ X520-DA2 SFP+   → Patch 9 → CRS310-1G-5S-4S+IN SFP+ 1    │  │  │
│  │      │ 2x E5-2699v3  │  256GB DDR4  │  PERC H730                │  │  │
│  │      │ LSI 9207-8e HBA → SAS SFF-8088 to MD1200                 │  │  │
│  │      │ USB             → NUT (UPS monitoring)                   │  │  │
│  │      └──────────────────────────────────────────────────────────┘  │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │ 2U   DELL MD1220 - 24x 2.5" SFF DISK SHELF                         │  │
│  │      ┌──────────────────────────────────────────────────────────┐  │  │
│  │      │ ◇ SAS ◇   ┌─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┐                      │  │  │
│  │      │ EMM       │0│1│2│3│4│5│6│7│8│9│A│B│                      │  │  │
│  │      │           ├─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┤                      │  │  │
│  │      │           │C│D│E│F│G│H│I│J│K│L│M│N│                      │  │  │
│  │      │           └─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┘                      │  │  │
│  │      │ 24x 2.5" SAS/SATA → R730xd HBA (passthrough to VM)       │  │  │
│  │      │ Dual EMM  │  Dual PSU  │  TrueNAS SCALE Primary          │  │  │
│  │      └──────────────────────────────────────────────────────────┘  │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │ 2U   DELL R730xd (din) - PROXMOX VE (TrueNAS SCALE VM)             │  │
│  │      ┌──────────────────────────────────────────────────────────┐  │  │
│  │      │ LOM 1GbE        → Patch 4 → CRS310-8G+2S+IN Port 5       │  │  │
│  │      │ iDRAC           → Patch 2 → CRS310-8G+2S+IN Port 3       │  │  │
│  │      │ X520-DA2 SFP+   → Patch 10 → CRS310-1G-5S-4S+IN SFP+ 2   │  │  │
│  │      │ 2x E5-2680v3  │  128GB DDR4  │  8x 3.5" internal         │  │  │
│  │      │ LSI 9207-8e HBA (IT mode) → SAS SFF-8088 to MD1220       │  │  │
│  │      │ NVMe Boot                                                │  │  │
│  │      └──────────────────────────────────────────────────────────┘  │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │ 2U   DELL MD1200 - 12x 3.5" LFF DISK SHELF                         │  │
│  │      ┌──────────────────────────────────────────────────────────┐  │  │
│  │      │ ◇ SAS ◇   ┌─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┐                      │  │  │
│  │      │ EMM       │0│1│2│3│4│5│6│7│8│9│A│B│                      │  │  │
│  │      │           └─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┘                      │  │  │
│  │      │ 12x 3.5" SAS/SATA → R630 HBA                             │  │  │
│  │      │ Dual EMM  │  Dual PSU  │  TrueNAS Backup VM              │  │  │
│  │      └──────────────────────────────────────────────────────────┘  │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │ 2U   UPS - APC SMT1500RMI2U (1500VA/1000W)                         │  │
│  │      ┌──────────────────────────────────────────────────────────┐  │  │
│  │      │ ◉ ◉ ◉ ◉ ◉ ◉ ◉ ◉   BATTERY BACKUP OUTLETS (C13)           │  │  │
│  │      │ 1 2 3 4 5 6 7 8   (Powers all devices via PDU)           │  │  │
│  │      │                                                          │  │  │
│  │      │ [LCD] Runtime: ~12min  │  Load: 71%  │  USB→NUT→Proxmox  │  │  │
│  │      │ Line-Interactive  │  RBC133 Battery  │  NUT Compatible   │  │  │
│  │      └──────────────────────────────────────────────────────────┘  │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘

TOTAL: 18U (FULLY POPULATED)
  - 1U   Keystone Patch Panel (24-port: 6x Cat6A, 3x LC Fiber, 15x Blank)
  - 1U   Network Shelf (Beryl AX + Pi-hole)
  - 1U   NeatPatch Cable Management
  - 1U   MikroTik Switch Shelf (CRS310-8G+2S+IN + CRS310-1G-5S-4S+IN)
  - 1U   Brush Panel (cable pass-through)
  - 4U   Blank/Vented Panels (future expansion)
  - 1U   Dell R630 "grogu" (Proxmox VE + TrueNAS Backup VM)
  - 2U   Dell MD1220 (24x 2.5" SFF → SAS to R730xd)
  - 2U   Dell R730xd "din" (Proxmox VE + TrueNAS SCALE VM)
  - 2U   Dell MD1200 (12x 3.5" LFF → SAS to R630)
  - 2U   UPS (APC SMT1500RMI2U)

PDUs: Intellinet PDU (existing) + fan controller - rear-mounted (0U)
```

## Patch Panel Port Assignments

| Port | Keystone | Back (Device) | Front (Patch to) |
|------|----------|---------------|------------------|
| 1 | Cat6A RJ45 | grogu iDRAC | CRS310-8G+2S+IN Port 2 |
| 2 | Cat6A RJ45 | din iDRAC | CRS310-8G+2S+IN Port 3 |
| 3 | Cat6A RJ45 | grogu LOM | CRS310-8G+2S+IN Port 4 |
| 4 | Cat6A RJ45 | din LOM | CRS310-8G+2S+IN Port 5 |
| 5 | Cat6A RJ45 | Pi-hole eth0 | CRS310-8G+2S+IN Port 6 |
| 6 | Cat6A RJ45 | sorgan LAN | CRS310-8G+2S+IN Port 1 |
| 7-8 | Blank | — | — |
| 9 | LC Duplex OM4 | grogu X520-DA2 | CRS310-1G-5S-4S+IN SFP+ 1 |
| 10 | LC Duplex OM4 | din X520-DA2 | CRS310-1G-5S-4S+IN SFP+ 2 |
| 11 | LC Duplex OM4 | GPU server | CRS310-1G-5S-4S+IN SFP+ 3 |
| 12-24 | Blank | — | — |

## Network Architecture (Two-Switch Design)

### Switch Interconnect
| From | To | Cable | Purpose |
|------|-----|-------|---------|
| CRS310-8G+2S+IN SFP+ 1 | CRS310-1G-5S-4S+IN SFP+ 4 | 10G DAC | VLAN trunk (all VLANs) |

### CRS310-1G-5S-4S+IN (10G Aggregation Layer)

| Port | Device | VLAN | IP |
|------|--------|------|-----|
| SFP+ 1 | grogu X520-DA2 | 10 (Storage) | 10.10.10.10 |
| SFP+ 2 | din X520-DA2 | 10 (Storage) | 10.10.10.11 |
| SFP+ 3 | GPU server | 10 (Storage) | 10.10.10.12 |
| SFP+ 4 | CRS310-8G+2S+IN trunk | trunk | — |
| SFP 1-5 | (future 1G fiber/copper) | — | — |
| GbE | management | 1 (Mgmt) | 10.10.1.2 |

### CRS310-8G+2S+IN (L3 Core / Inter-VLAN Router)

| Port | Device | VLAN | IP |
|------|--------|------|-----|
| SFP+ 1 | CRS310-1G-5S-4S+IN trunk | trunk | — |
| SFP+ 2 | (future 10G) | — | — |
| Port 1 | sorgan (Beryl AX) | 20 (LAN) | 192.168.0.1 |
| Port 2 | grogu iDRAC | 1 (Mgmt) | 10.10.1.10 |
| Port 3 | din iDRAC | 1 (Mgmt) | 10.10.1.11 |
| Port 4 | grogu LOM | 20 (LAN) | 192.168.0.10 |
| Port 5 | din LOM | 20 (LAN) | 192.168.0.11 |
| Port 6 | Pi-hole | 20 (LAN) | 192.168.0.53 |
| Port 7-8 | (available) | — | — |

### VLAN Gateways (on CRS310-8G+2S+IN)

| VLAN | Interface IP | Purpose |
|------|--------------|---------|
| 1 | 10.10.1.1/24 | Management gateway |
| 10 | 10.10.10.1/24 | Storage gateway |
| 20 | 192.168.0.254/24 | LAN gateway (Pi-hole points here) |

Note: TrueNAS SCALE VM (192.168.0.13) runs on din (R730xd) Proxmox, accessed via bridge.

## Direct Connections (Storage - Non-Switched)

| Source | Target | Cable |
|--------|--------|-------|
| grogu (R630) LSI 9207-8e | Dell MD1200 EMM | Mini-SAS SFF-8088 |
| din (R730xd) LSI 9207-8e | Dell MD1220 EMM | Mini-SAS SFF-8088 |

## VLAN Summary

| VLAN | Name | Subnet | Purpose |
|------|------|--------|---------|
| 1 | Management | 10.10.1.0/24 | iDRAC, switch mgmt |
| 10 | Storage | 10.10.10.0/24 | NFS, iSCSI, replication |
| 20 | LAN | 192.168.0.0/24 | VMs, services, clients |

## Power Budget

| Device | Idle | Load |
|--------|------|------|
| R630 | 120W | 200W |
| MD1220 | 60W | 100W |
| R730xd | 150W | 250W |
| MD1200 | 80W | 120W |
| Network | 30W | 40W |
| **Total** | **~440W** | **~710W** |

UPS: APC SMT1500RMI2U (1000W) → ~71% max load, ~12min runtime

## PDU Layout (Rear-Mounted)

```
Existing Intellinet PDU + Fan Controller (rear rails)
─────────────────────────────────────────────────────
R630 PSU1 + PSU2
MD1220 PSU1 + PSU2
R730xd PSU1 + PSU2
MD1200 PSU1 + PSU2
Network gear
```

Note: Single PDU may require second PDU for redundancy if desired.

## Shopping List

| Item | Qty | Price |
|------|-----|-------|
| **Networking** |
| MikroTik CRS310-8G+2S+IN (L3 Core) | 1 | ~€180 / $200 |
| MikroTik CRS310-1G-5S-4S+IN (10G Agg) | 1 | ~€163 / $199 |
| 1U Rack Shelf (for both switches) | 1 | ~€15-25 |
| 10G DAC cable (switch interconnect) | 1 | ~€15-20 |
| **Rack & Power** |
| 18U Acoustic Cabinet (existing) | — | — |
| APC SMT1500RMI2U (refurb) | 1 | €329-400 |
| Vertical PDU (optional, for redundancy) | 1 | €40-70 |
| **Cable Management** |
| 1U NeatPatch Cable Manager | 1 | €40-60 |
| 1U Brush Panel | 1 | €10-20 |
| 1U Blank/Vented Panels | 4 | €20-30 |
| **Patch Panel** |
| 24-port Keystone Patch Panel 1U | 1 | €15-25 |
| Cat6A RJ45 Keystone Jacks | 6 | €15-20 |
| LC Duplex OM4 Keystone | 3 | €12-20 |
| Keystone Blanks | 15 | €5-10 |
| **Copper Cabling** |
| Cat6A Patch Cable 0.3m | 6 | €12-18 |
| Cat6A Patch Cable 0.5m | 2 | €5-8 |
| Cat6A Patch Cable 1m | 4 | €8-12 |
| **Fiber Cabling** |
| 10G-SR SFP+ Transceiver | 6 | €45-75 |
| LC-LC OM4 Duplex 0.3m | 3 | €9-15 |
| LC-LC OM4 Duplex 1m | 2 | €8-12 |
| **Storage Connectivity** |
| Mini-SAS SFF-8088 cable | 2 | €15-25 each |
| LSI 9207-8e HBA (for R630) | 1 | €30-50 |
| **Power Cables** |
| C13 power cables | 8 | €15-25 |

**Network Total: ~€343 / ~$400**
