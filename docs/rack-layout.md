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
│  │      + PI SHELF (rear-mounted)                                     │  │
│  │      ┌───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┐             │  │
│  │      │ 1 │ 2 │ 3 │ 4 │ 5 │ 6 │ 7 │ 8 │ 9 │10 │11 │12 │             │  │
│  │      │WAN│AP │Pi │QD │iDR│iDR│   │   │LC │LC │   │   │             │  │
│  │      │HSp│Brl│hol│ev │gro│din│ — │ — │gro│din│ — │ — │             │  │
│  │      └───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┘             │  │
│  │      ┌───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┐             │  │
│  │      │13 │14 │15 │16 │17 │18 │19 │20 │21 │22 │23 │24 │             │  │
│  │      │   │   │   │   │   │   │   │   │   │   │   │   │             │  │
│  │      └───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┘             │  │
│  │      REAR: ┌──────────────┐  ┌──────────────┐                      │  │
│  │            │   Pi-hole    │  │   QDevice    │                      │  │
│  │            │   (Pi 4B)    │  │   (Pi 4B)    │                      │  │
│  │            └──────────────┘  └──────────────┘                      │  │
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
│  │ 6U   ACOUSTIC BLANKING PANELS (3× 2U sound-dampening)              │  │
│  │      ┌────────────────────────────────────────────────────────┐    │  │
│  │      │ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ │    │  │
│  │      │ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ │    │  │
│  │      │ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ │    │  │
│  │      └────────────────────────────────────────────────────────┘    │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│  ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐     │
│            ▲ HEAD END (9U) ───────────── COMPUTE (9U) ▼                  │
│  └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘     │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │ 1U   DELL R630 (grogu) - PROXMOX VE                                │  │
│  │      ┌──────────────────────────────────────────────────────────┐  │  │
│  │      │ iDRAC           → Patch 5 → CRS310 ether5                │  │  │
│  │      │ X520-DA2 SFP+   → Patch 9 → CRS310 SFP+ 1                │  │  │
│  │      │ 2× E5-2699v3  │  256GB DDR4  │  2× SSD (SATA)            │  │  │
│  │      │ HPE H241 HBA    → SAS to MD1200                          │  │  │
│  │      │ USB             → NUT (UPS monitoring)                   │  │  │
│  │      └──────────────────────────────────────────────────────────┘  │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │ 2U   DELL MD1200 - 12× 3.5" LFF DISK SHELF                         │  │
│  │      ┌──────────────────────────────────────────────────────────┐  │  │
│  │      │ ◇ SAS ◇   ┌─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┐                      │  │  │
│  │      │ EMM       │0│1│2│3│4│5│6│7│8│9│A│B│                      │  │  │
│  │      │           └─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┘                      │  │  │
│  │      │ 12× 8TB SATA (backup) → grogu HPE H241                   │  │  │
│  │      │ Dual EMM  │  Dual PSU  │  TrueNAS Backup VM              │  │  │
│  │      └──────────────────────────────────────────────────────────┘  │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │ 2U   DELL R730xd (din) - PROXMOX VE (TrueNAS SCALE VM)             │  │
│  │      ┌──────────────────────────────────────────────────────────┐  │  │
│  │      │ iDRAC           → Patch 6 → CRS310 ether4                │  │  │
│  │      │ X520-DA2 SFP+   → Patch 10 → CRS310 SFP+ 2               │  │  │
│  │      │ 2× E5-2680v3  │  128GB DDR4  │  NVMe Boot                │  │  │
│  │      │ H330 Mini       → 6×8TB bulk + 6×3TB scratch (internal)  │  │  │
│  │      │ PERC H200E HBA  → SAS to MD1220                          │  │  │
│  │      └──────────────────────────────────────────────────────────┘  │  │
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
│  │      │ 21× 900GB SAS + 2× 120GB SSD (fast) → din PERC H200E     │  │  │
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
│  │      │ [LCD] Runtime: ~12min  │  Load: 71%  │  USB→NUT→Proxmox  │  │  │
│  │      │ Line-Interactive  │  RBC133 Battery  │  NUT Compatible   │  │  │
│  │      └──────────────────────────────────────────────────────────┘  │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘

ON TOP: O2 Homespot (WAN modem) + Beryl AX WiFi AP (sorgan)

TOTAL: 18U (FULLY POPULATED)
  - 1U   Keystone Patch Panel (front) + Pi Shelf (rear: Pi-hole + QDevice)
  - 1U   NeatPatch Cable Management
  - 1U   MikroTik CRS310-8G+2S+IN "nevarro" (rack-mounted, gateway / L3 / firewall)
  - 6U   Acoustic Blanking Panels (3× 2U sound-dampening)
  - 1U   Dell R630 "grogu" (Proxmox VE)
  - 2U   Dell MD1200 (12× 3.5" LFF → SAS to grogu)
  - 2U   Dell R730xd "din" (Proxmox VE + TrueNAS SCALE VM)
  - 2U   Dell MD1220 (24× 2.5" SFF → SAS to din)
  - 2U   UPS (APC SMT1500RMI2U)

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
- QDevice (rear U1) → Patch 4 back, 0.1m Cat6A

**From servers** (up rear → through NeatPatch rear grommets → into patch panel back, U1):

- grogu iDRAC (U10) → up rear → NeatPatch grommet (U2) → Patch 5 back
- din iDRAC (U13) → up rear → NeatPatch grommet (U2) → Patch 6 back
- grogu X520 SFP+ (U10) → up rear → NeatPatch grommet (U2) → Patch 9 back, LC fiber
- din X520 SFP+ (U13) → up rear → NeatPatch grommet (U2) → Patch 10 back, LC fiber

**Front patch cables** (all managed by NeatPatch, U1 front → U2 fingers → U3):

- Patch 1 front → Nevarro ether1 (WAN)
- Patch 2 front → Nevarro ether3 (Beryl AP)
- Patch 3 front → Nevarro ether2 (Pi-hole)
- Patch 4 front → Nevarro ether6 (QDevice)
- Patch 5 front → Nevarro ether5 (grogu iDRAC)
- Patch 6 front → Nevarro ether4 (din iDRAC)
- Patch 9 front → Nevarro SFP+ 1 (grogu 10GbE)
- Patch 10 front → Nevarro SFP+ 2 (din 10GbE)

**Direct SAS** (server → shelf, no switch):

- grogu HPE H241 (U10) → MD1200 EMM (U11-U12), Mini-SAS HD SFF-8644 to SFF-8088
- din PERC H200E (U13) → MD1220 EMM (U15-U16), Mini-SAS SFF-8088

## Patch Panel Port Assignments (U1)

| Port | Keystone | Back (Device) | Front (Patch to) |
| ---- | -------- | ------------- | ----------------- |
| 1 | Cat6A RJ45 | O2 Homespot (from top) | Nevarro ether1 |
| 2 | Cat6A RJ45 | Beryl AP (from top) | Nevarro ether3 |
| 3 | Cat6A RJ45 | Pi-hole (rear shelf) | Nevarro ether2 |
| 4 | Cat6A RJ45 | QDevice (rear shelf) | Nevarro ether6 |
| 5 | Cat6A RJ45 | grogu iDRAC (via rear) | Nevarro ether5 |
| 6 | Cat6A RJ45 | din iDRAC (via rear) | Nevarro ether4 |
| 7-8 | Blank | — | — |
| 9 | LC Duplex OM4 | grogu X520-DA2 (via rear) | Nevarro SFP+ 1 |
| 10 | LC Duplex OM4 | din X520-DA2 (via rear) | Nevarro SFP+ 2 |
| 11-24 | Blank | — | — |

## MikroTik CRS310-8G+2S+IN (nevarro)

Gateway, NAT, firewall, DHCP, DNS forwarding. Managed via Terragrunt.

| Port | Device | Mode | VLAN | IP |
| ---- | ------ | ---- | ---- | -- |
| ether1 | O2 Homespot (via patch 1) | WAN (standalone) | — | 192.168.8.2 |
| ether2 | Pi-hole (via patch 3) | access | 20 (LAN) | 192.168.0.53 |
| ether3 | Beryl AP (via patch 2) | access | 20 (LAN) | DHCP |
| ether4 | din iDRAC (via patch 6) | access | 1 (Mgmt) | 10.10.1.11 |
| ether5 | grogu iDRAC (via patch 5) | access | 1 (Mgmt) | 10.10.1.10 |
| ether6 | QDevice (via patch 4) | access | 20 (LAN) | 192.168.0.54 |
| ether7-8 | (available) | — | — | — |
| SFP+ 1 | grogu X520-DA2 (via patch 9) | trunk (all VLANs) | tagged | — |
| SFP+ 2 | din X520-DA2 (via patch 10) | trunk (all VLANs) | tagged | — |

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
| grogu (R630) | HPE H241 | Dell MD1200 EMM | Mini-SAS HD SFF-8644 to SFF-8088 |
| din (R730xd) | Dell PERC H200E | Dell MD1220 EMM | Mini-SAS SFF-8088 |

## VLAN Summary

| VLAN | Name | Subnet | Purpose |
| ---- | ---- | ------ | ------- |
| 1 | Management | 10.10.1.0/24 | iDRAC, switch mgmt |
| 10 | Storage | 10.10.10.0/24 | NFS, iSCSI, replication (10GbE) |
| 20 | LAN | 192.168.0.0/24 | VMs, services, clients, WiFi |
| 30 | K8s Shared | 10.0.1.0/24 | Kubernetes shared services |
| 31 | K8s Apps | 10.0.2.0/24 | Kubernetes production apps |
| 32 | K8s Test | 10.0.3.0/24 | Kubernetes testing/staging |

## Power Budget

| Device | Idle | Load |
| ------ | ---- | ---- |
| R630 (grogu) — 2× E5-2699v3, 256GB, 2× SSD | 150W | 350W |
| MD1200 — 12× 8TB 3.5" SATA | 100W | 150W |
| R730xd (din) — 2× E5-2680v3, 128GB, 12× internal drives | 200W | 400W |
| MD1220 — 21× 900GB + 2× 120GB SSD 2.5" SAS/SATA | 150W | 200W |
| Network — CRS310, 2× Pi 4B, Beryl AX, Homespot | 40W | 50W |
| **Total** | **~640W** | **~1150W** |

UPS: APC SMT1500RMI2U (1500VA / 1000W) → ~64% idle load, ~8min runtime at full load

## PDU Layout (Rear-Mounted, 2× PDU from UPS)

```text
PDU A (rear left rail)          PDU B (rear right rail)
───────────────────────         ───────────────────────
R630 PSU1                       R630 PSU2
MD1200 PSU1                     MD1200 PSU2
R730xd PSU1                     R730xd PSU2
MD1220 PSU1                     MD1220 PSU2
CRS310 + 2× Pi 4B
```
