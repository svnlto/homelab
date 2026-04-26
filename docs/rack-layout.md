# Physical Rack Layout (18U Acoustic Cabinet)

> **See also**: [network-architecture.md](network-architecture.md) for detailed
> VLAN configuration, IP allocations, and traffic flows.

```text
┌──────────────────────────────────────────────────────────────────────────┐
│                          19" RACK - FRONT VIEW                           │
│                       (18U Acoustic Cabinet, 1000mm deep)                │
│                         19" Tech / Intellinet                            │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ╔════════════════════════════════════════════════════════════════════╗  │
│  ║  ON TOP OF RACK (external, not racked)                             ║  │
│  ║  ┌────────────────────┐  ┌────────────────────┐                    ║  │
│  ║  │   O2 Homespot      │  │     BERYL AX       │                    ║  │
│  ║  │   (WAN modem)      │  │     (sorgan)       │                    ║  │
│  ║  │   192.168.8.1      │  │  WiFi AP (VLAN 20) │                    ║  │
│  ║  └────────────────────┘  └────────────────────┘                    ║  │
│  ╚════════════════════════════════════════════════════════════════════╝  │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │ 1U   KEYSTONE PATCH PANEL (24-port, front)                         │  │
│  │      + PI SHELF (rear-mounted, Pi-hole only)                       │  │
│  │      ┌───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┐             │  │
│  │      │ 1 │ 2 │ 3 │ 4 │ 5 │ 6 │ 7 │ 8 │ 9 │10 │11 │12 │             │  │
│  │      │WAN│AP │Pi │   │AMT│   │   │   │LC │   │   │   │             │  │
│  │      │HSp│Brl│hol│ — │gro│ — │ — │ — │gro│ — │ — │ — │             │  │
│  │      └───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┘             │  │
│  │      ┌───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┐             │  │
│  │      │13 │14 │15 │16 │17 │18 │19 │20 │21 │22 │23 │24 │             │  │
│  │      │   │   │   │   │   │   │   │   │   │   │   │   │             │  │
│  │      └───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┘             │  │
│  │      REAR: ┌──────────────┐                                         │  │
│  │            │   Pi-hole    │                                         │  │
│  │            │   (Pi 4B)    │                                         │  │
│  │            └──────────────┘                                         │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │ 1U   NEATPATCH CABLE MANAGEMENT                                    │  │
│  │      ┌──────────────────────────────────────────────────────────┐  │  │
│  │      │ ≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋≋   │  │  │
│  │      │ Front: patch cables from panel (U1) down to switch (U3)  │  │  │
│  │      │ Rear:  grommeted pass-throughs for server cables         │  │  │
│  │      └──────────────────────────────────────────────────────────┘  │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │ 1U   MIKROTIK CRS310-8G+2S+IN (nevarro) - rack-mounted             │  │
│  │      ┌──────────────────────────────────────────────────────────┐  │  │
│  │      │   Gateway / L3 / FW      ○○○○○○○○ ◇◇                     │  │  │
│  │      │                          8×2.5G    2×SFP+                │  │  │
│  │      └──────────────────────────────────────────────────────────┘  │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │ 13U  ACOUSTIC BLANKING PANELS (free space after consolidation)     │  │
│  │      ┌────────────────────────────────────────────────────────┐    │  │
│  │      │ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ │    │  │
│  │      │ (freed: R630 1U + MD1200 2U + R730xd 2U + old blanks) │    │  │
│  │      └────────────────────────────────────────────────────────┘    │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │ 2U   DELL MD1220 - 24× 2.5" SFF DISK SHELF                         │  │
│  │      ┌──────────────────────────────────────────────────────────┐  │  │
│  │      │ ◇ SAS ◇   ┌─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┐                      │  │  │
│  │      │ EMM       │0│1│2│3│4│5│6│7│8│9│A│B│                      │  │  │
│  │      │           ├─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┤                      │  │  │
│  │      │           │C│D│E│F│G│H│I│J│K│L│M│N│                      │  │  │
│  │      │           └─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┘                      │  │  │
│  │      │ 21× 900GB SAS + 2× 120GB SSD (fast) → grogu external HBA │  │  │
│  │      │ Dual EMM  │  Dual PSU  │  TrueNAS Primary VM             │  │  │
│  │      └──────────────────────────────────────────────────────────┘  │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │ 2U   UPS - APC SMT1500RMI2U (1500VA/1000W)                         │  │
│  │      ┌──────────────────────────────────────────────────────────┐  │  │
│  │      │ ◉ ◉ ◉ ◉ ◉ ◉ ◉ ◉   BATTERY BACKUP OUTLETS (C13)           │  │  │
│  │      │ 1 2 3 4 5 6 7 8   (Powers all devices via PDU)           │  │  │
│  │      │                                                          │  │  │
│  │      │ [LCD] Runtime: ~30min  │  Load: ~30%  │  USB→NUT→Proxmox  │  │  │
│  │      │ Line-Interactive  │  RBC133 Battery  │  NUT Compatible   │  │  │
│  │      └──────────────────────────────────────────────────────────┘  │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘

ON TOP: O2 Homespot (WAN modem) + Beryl AX WiFi AP (sorgan)

BESIDE RACK (floor/adjacent, tower workstation):
  ┌─────────────────────────────────────────┐
  │  Lenovo ThinkStation P700 (grogu)        │
  │  Proxmox VE — single compute node        │
  │  AMT (Intel)  → Patch 5 → CRS310 ether4 │
  │  Arc A310 GPU + 2× HBA + 10GbE SFP+ NIC │
  │  Internal HBA  → bulk pool drives        │
  │  External HBA  → SAS to MD1220 (fast)   │
  │  10GbE SFP+    → Patch 9 → CRS310 SFP+1 │
  └─────────────────────────────────────────┘

TOTAL: 18U (partially populated — 13U free)
  - 1U   Keystone Patch Panel (front) + Pi Shelf (rear: Pi-hole only)
  - 1U   NeatPatch Cable Management
  - 1U   MikroTik CRS310-8G+2S+IN "nevarro" (rack-mounted, gateway / L3 / firewall)
  - 13U  Acoustic Blanking Panels (free space)
  - 2U   Dell MD1220 (24× 2.5" SFF → SAS to grogu P700 external HBA)
  - 2U   UPS (APC SMT1500RMI2U)

NOT IN RACK (beside rack, floor):
  - Lenovo ThinkStation P700 "grogu" (Proxmox VE, tower)
    - Intel Arc A310 GPU
    - Internal HBA → bulk pool drives (in P700 bays)
    - External HBA → Dell MD1220 (fast pool)
    - 10GbE SFP+ NIC → CRS310 SFP+ 1

PDUs: Intellinet PDU (existing) + fan controller - rear-mounted (0U)
```

## Cable Paths

All connections route through the patch panel (U1). On the front side,
short patch cables drop from the panel through NeatPatch (U2) into Nevarro (U3).
On the back side, cables arrive from devices above, beside, or below the panel.

**From top of rack** (into patch panel back, U1):

- O2 Homespot (top) → Patch 1 back, 0.5m Cat6A
- Beryl AP (top) → Patch 2 back, 0.5m Cat6A

**From rear Pi shelf** (into patch panel back, U1):

- Pi-hole (rear U1) → Patch 3 back, 0.1m Cat6A

**From P700 beside rack** (cable run from tower to rack rear → patch panel back, U1):

- grogu AMT (P700) → Patch 5 back, Cat6A
- grogu Arc A310 / 10GbE SFP+ (P700) → Patch 9 back, LC fiber

**Front patch cables** (all managed by NeatPatch, U1 front → U2 fingers → U3):

- Patch 1 front → Nevarro ether1 (WAN)
- Patch 2 front → Nevarro ether3 (Beryl AP)
- Patch 3 front → Nevarro ether2 (Pi-hole)
- Patch 5 front → Nevarro ether4 (grogu AMT)
- Patch 9 front → Nevarro SFP+ 1 (grogu 10GbE)

**Direct SAS** (P700 external HBA → shelf, no switch):

- grogu external HBA (P700) → MD1220 EMM (rack), Mini-SAS SFF-8088

## Patch Panel Port Assignments (U1)

| Port | Keystone | Back (Device) | Front (Patch to) |
| ---- | -------- | ------------- | ----------------- |
| 1 | Cat6A RJ45 | O2 Homespot (from top) | Nevarro ether1 |
| 2 | Cat6A RJ45 | Beryl AP (from top) | Nevarro ether3 |
| 3 | Cat6A RJ45 | Pi-hole (rear shelf) | Nevarro ether2 |
| 4 | Blank | — | — |
| 5 | Cat6A RJ45 | grogu AMT (via cable run) | Nevarro ether4 |
| 6-8 | Blank | — | — |
| 9 | LC Duplex OM4 | grogu 10GbE SFP+ (via cable run) | Nevarro SFP+ 1 |
| 10-24 | Blank | — | — |

## MikroTik CRS310-8G+2S+IN (nevarro)

Gateway, NAT, firewall, DHCP, DNS forwarding. Managed via Terragrunt.

| Port | Device | Mode | VLAN | IP |
| ---- | ------ | ---- | ---- | -- |
| ether1 | O2 Homespot (via patch 1) | WAN (standalone) | — | 192.168.8.2 |
| ether2 | Pi-hole (via patch 3) | access | 20 (LAN) | 192.168.0.53 |
| ether3 | Beryl AP (via patch 2) | access | 20 (LAN) | DHCP |
| ether4 | (available) | — | — | — |
| ether4 | grogu AMT (via patch 5) | access | 1 (Mgmt) | 10.10.1.10 |
| ether6-8 | (available) | — | — | — |
| SFP+ 1 | grogu 10GbE SFP+ (via patch 9) | trunk (all VLANs) | tagged | — |
| SFP+ 2 | (available) | — | — | — |

### VLAN Gateways

| VLAN | Interface IP | Purpose |
| ---- | ------------ | ------- |
| 1 | 10.10.1.1/24 | Management gateway |
| 10 | 10.10.10.1/24 | Storage gateway (10GbE) |
| 20 | 192.168.0.1/24 | LAN gateway |
| 30 | 10.0.1.1/24 | K8s shared services |
| 31 | 10.0.2.1/24 | K8s production apps |
| 32 | 10.0.3.1/24 | K8s testing/staging |

## Direct SAS Connections (Non-Switched)

| Source | HBA | Target | Cable |
| ------ | --- | ------ | ----- |
| grogu (P700) | External HBA | Dell MD1220 EMM | Mini-SAS SFF-8088 |

## VLAN Summary

| VLAN | Name | Subnet | Purpose |
| ---- | ---- | ------ | ------- |
| 1 | Management | 10.10.1.0/24 | AMT, switch mgmt |
| 10 | Storage | 10.10.10.0/24 | NFS, iSCSI, replication (10GbE) |
| 20 | LAN | 192.168.0.0/24 | VMs, services, clients, WiFi |
| 30 | K8s Shared | 10.0.1.0/24 | Kubernetes shared services |
| 31 | K8s Apps | 10.0.2.0/24 | Kubernetes production apps |
| 32 | K8s Test | 10.0.3.0/24 | Kubernetes testing/staging |

## Power Budget

| Device | Idle | Load |
| ------ | ---- | ---- |
| P700 (grogu) — all VMs + bulk drives in bays | ~200W | ~400W |
| MD1220 — 21× 900GB + 2× 120GB SSD 2.5" SAS/SATA | 150W | 200W |
| Network — CRS310, 1× Pi 4B, Beryl AX, Homespot | 35W | 45W |
| **Total** | **~385W** | **~645W** |

UPS: APC SMT1500RMI2U (1500VA / 1000W) → ~39% idle load, ~30min runtime at idle load

## PDU Layout (Rear-Mounted, 2× PDU from UPS)

```text
PDU A (rear left rail)          PDU B (rear right rail)
───────────────────────         ───────────────────────
P700 PSU1                       P700 PSU2
MD1220 PSU1                     MD1220 PSU2
CRS310 + Pi 4B
```
