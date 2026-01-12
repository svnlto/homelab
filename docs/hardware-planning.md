# Homelab Hardware Planning - January 2026

## Overview

This document captures the final hardware configuration for a 2-node Proxmox cluster:

- **r630**: Pure compute node (Proxmox)
- **r730xd**: Storage + compute node (Proxmox + TrueNAS VM)
- **DS2246**: External disk shelf (24x 2.5" SFF)
- **Use cases**: Kubernetes/OpenShift learning, Karpenter simulation, Jellyfin transcoding, LLM inference

## Final Architecture

### Hardware Acquired

**Dell R730xd (Storage + Compute)**
- **Price:** €270 (barebone from eBay.de)
- **Form Factor:** 2U rack server
- **Drive Bays:** 16x LFF + 2x SFF (rear)
- **Boot Drives:** 2x SATA SSD in rear SFF slots (Proxmox + TrueNAS VM boot)
- **Data Storage:** 5x 8TB 3.5" LFF drives (TrueNAS data pool)
- **CPUs:** 2x E5-2680 v3 (12C/24T each = 24C/48T total, 2.5 GHz base, 120W TDP)
- **RAM:** To be installed (DDR4 ECC)
- **HBA Controllers:**
  - Dell H330 Mini (flashed to IT mode) → passthrough to TrueNAS VM for internal drives
  - LSI 9201-8e PCIe card → external connection to DS2246 shelf
- **Network:** 10GbE SFP+ (onboard or add-in card)

**Dell R630 (Pure Compute)**
- **Price:** €100 (acquired from eBay.de)
- **Form Factor:** 1U rack server
- **Drive Bays:** 8x 2.5" SFF (local storage)
- **Boot Drive:** 1x SATA drive in optical bay (Proxmox boot)
- **PCIe Slots:** 3x low-profile slots
- **CPUs:** 2x E5-2699 v3 (18C/36T each = 36C/72T total, pre-installed)
- **RAM:** DDR4 ECC (pre-installed)
- **Network:** 2x 10GbE SFP+ ports (onboard daughter card/NDC)
- **GPU:** Sparkle Arc A310 Eco (low-profile, for Jellyfin transcoding)

**NetApp DS2246 Disk Shelf**
- **Price:** €149-199 (eBay.de)
- **Capacity:** 24x 2.5" SFF bays
- **Current:** 24x 2.5" SFF drives
- **Connection:** SFF-8088 SAS cables to r730xd's LSI 9201-8e HBA
- **IOM Modules:** 2x IOM6 (dual SAS ports per module)
- **Power:** Dual PSU (redundant)

### Network Topology

```text
Internet → Router (192.168.1.1)
              ↓
         Pi-hole DNS
         192.168.1.2
         (Raspberry Pi)
              ↓
    ┌─────────┼─────────┐
    ↓                   ↓
  r630               r730xd
  Proxmox            Proxmox + TrueNAS VM
  10.0.0.2           10.0.0.1
    ↓                   ↓
    └───── 10GbE DAC ───┘
         (Direct Connection)
              ↓
         r730xd → DS2246
         (SFF-8088 SAS)
         24x SFF drives
```

**10GbE Direct Connection:**
- r630 ↔ r730xd via Cisco DAC cables
- Cluster communication (Corosync)
- Storage traffic (NFS/iSCSI from TrueNAS)
- No switch required (point-to-point)

**Storage Architecture:**
- **r730xd internal:** 5x 8TB LFF → TrueNAS VM (H330 passthrough)
- **DS2246 external:** 24x SFF → TrueNAS VM (9201-8e passthrough)
- **r630:** Mounts storage via 10GbE NFS/iSCSI

### TrueNAS VM Configuration

**VM Specifications:**
- **Host:** r730xd (pinned, cannot migrate due to passthrough)
- **vCPUs:** 4-6 cores
- **RAM:** 32-48GB (1GB per TB of storage for ZFS ARC)
- **Boot Disk:** 32GB virtual disk
- **Storage Controllers (passthrough):**
  - Dell H330 (IT mode) → 5x 8TB LFF drives
  - LSI 9201-8e → DS2246 with 24x SFF drives
- **Network:** 10GbE virtio NIC (or passthrough)

**Storage Pools:**
- Pool 1 (LFF): 5x 8TB drives → media, backups
- Pool 2 (SFF): 24x drives → VMs, containers, databases

### Cluster Configuration

**2-Node Proxmox Cluster:**
- **r630** (Node 1): Compute-focused, uses shared TrueNAS storage (no local VM storage)
- **r730xd** (Node 2): Storage + compute, TrueNAS VM pinned
- **Quorum:** 2-node cluster (manual failover acceptable for homelab)
  - Optional: Add Raspberry Pi as external quorum device
- **Shared Storage:** TrueNAS VM on r730xd via NFS/iSCSI
- **10GbE:** Direct connection via DAC cables

**Cluster Benefits:**
- Single Proxmox web UI for both nodes
- VM migration (non-storage VMs)
- Unified management
- HA foundation (with external quorum device)

## Dell Server Specifications

### R730 vs R730xd

| Feature | R730 | R730xd |
|---------|------|--------|
| Form Factor | 2U Rack | 2U Rack |
| Sockets | 2x LGA 2011-3 | 2x LGA 2011-3 |
| CPU Support | E5-2600 v3/v4 | E5-2600 v3/v4 |
| RAM Type | DDR4 ECC RDIMM/LRDIMM | DDR4 ECC RDIMM/LRDIMM |
| RAM Slots | 24 | 24 |
| Max RAM | 768GB | 768GB |
| Drive Bays | 8x SFF or 8x LFF | **12x LFF** or 24x SFF (+2 rear) |
| Hot-Swap | Yes | Yes |
| PCIe Bifurcation | Yes (native) | Yes (native) |
| Remote Management | iDRAC 8 Enterprise | iDRAC 8 Enterprise |
| Redundant PSU | Yes | Yes |
| Onboard Network | 4x 1GbE | 4x 1GbE (some have **2x 10GbE SFP+**) |
| Noise Level | 35-50 dB | 35-50 dB |
| Idle Power | 100-150W | 120-180W |
| Depth | ~750mm | ~750mm |

### R630 (1U Compute Node)

| Feature | Specification |
|---------|---------------|
| Form Factor | 1U Rack |
| Sockets | 2x LGA 2011-3 |
| CPU Support | E5-2600 v3/v4 |
| RAM Type | DDR4 ECC RDIMM/LRDIMM |
| RAM Slots | 24 |
| Max RAM | 768GB |
| Drive Bays | 8x or 10x SFF (2.5") |
| Hot-Swap | Yes |
| PCIe Bifurcation | Yes (native) |
| Remote Management | iDRAC 8 Enterprise |
| Redundant PSU | Yes (optional, some come with 1x) |
| Onboard Network | 4x 1GbE (some have 2x 10GbE SFP+) |
| GPU Support | **Low-profile only** (1U height limit) |
| Noise Level | Higher (40-55 dB - smaller fans) |
| Idle Power | ~80-120W |
| Best For | Compute-dense nodes without GPU |

**R630 Advantages:**
- ✓ 1U = higher density (4 nodes in 4U vs 2 in R730xd)
- ✓ Full dual-socket capability
- ✓ Lower cost than R730/R730xd
- ✓ Same CPU/RAM as R730 series
- ✓ Onboard 2x 10GbE SFP+ (no add-in card needed)
- ✓ Low-profile GPU support (Arc A310 for transcoding)

**R630 Limitations:**
- ✗ **3x low-profile PCIe slots only** (limits expansion cards)
- ✗ Louder than 2U (smaller fans = higher RPM)
- ✗ Limited to 8x SFF drives (no LFF support)

## HBA Controllers for TrueNAS

### Dell H330 Mini (Internal Drives)

**Purpose:** Passthrough to TrueNAS VM for r730xd internal drives

**Specifications:**
- **Interface:** 12Gb/s SAS
- **Ports:** 8 internal (mini-SAS HD SFF-8643)
- **Mode:** Must flash to IT/HBA mode (no RAID)
- **Drives Supported:** Up to 8x SATA/SAS drives
- **Form Factor:** Dell Mini PERC slot

**IT Mode Flashing:**
```bash
# Boot from DOS USB with Dell firmware tools
# Flash to IT firmware (removes RAID functionality)
# Allows direct disk access for ZFS
```

### LSI 9201-8e (External Shelf Connection)

**Purpose:** Connect to NetApp DS2246 disk shelf

**Specifications:**
- **Interface:** 6Gb/s SAS (compatible with DS2246 IOM6 modules)
- **Ports:** 2x external (SFF-8088)
- **Drives Supported:** Up to 8 drives per port = 16 total
- **Form Factor:** PCIe x8 low-profile card
- **Cable:** SFF-8088 to SFF-8088 (4x SAS lanes per cable)

**Connection to DS2246:**
- Cable 1: r730xd LSI 9201-8e port A → DS2246 IOM6 module A
- Cable 2: r730xd LSI 9201-8e port B → DS2246 IOM6 module B
- Redundant paths for reliability

## NetApp DS2246 Disk Shelf

### Specifications

- **Capacity:** 24x 2.5" SFF hot-swap bays
- **Interface:** 6Gb/s SAS (IOM6 modules)
- **Ports:** 2x IOM6 modules, 2x SFF-8088 ports each
- **Power:** Dual PSU (redundant, hot-swap)
- **Cooling:** 4x fans (redundant)
- **Weight:** ~25kg (55 lbs)
- **Depth:** 550mm / 21.7"

### IOM6 Module Connectivity

```text
DS2246 Rear:
┌─────────────────────────────┐
│   IOM6-A         IOM6-B     │
│  [0] [1]        [0] [1]     │ ← SFF-8088 ports
└─────────────────────────────┘

Connection options:
- Single-path: Cable from IOM6-A[0] to HBA
- Dual-path (recommended): Cable from IOM6-A[0] + IOM6-B[0] to HBA
```

### Pricing (eBay.de - January 2026)

| Configuration | Price |
|---------------|-------|
| Empty shelf + IOM6 modules | €80-120 |
| With 12-24x trays (empty) | €120-180 |
| With drives (varies by capacity) | €200-400+ |

## Cluster Resource Planning

### r630 (Compute Node)

**Configuration:**
- **CPUs:** 2x E5-2699 v3 (18C/36T each = 36C/72T total, 2.3 GHz, 145W TDP)
- **RAM:** 64-128GB DDR4 ECC (pre-installed)
- **GPU:** Intel Arc A310 Eco (low-profile, AV1 encode/decode)
- **Storage:** 1x SATA SSD in optical bay (Proxmox boot only), VM storage via TrueNAS network shares
- **Role:** Compute + GPU transcoding workloads

**Workload Examples:**
- Jellyfin VM with Arc A310 GPU passthrough (hardware transcoding)
- Kubernetes control plane + worker nodes
- OpenShift SNO
- Arr stack containers
- Development/test VMs

### r730xd (Storage + Compute Node)

**Configuration:**
- **CPUs:** 2x E5-2680 v3 (12C/24T each = 24C/48T total, 2.5 GHz, 120W TDP)
- **RAM:** 128-192GB DDR4 ECC
  - 32-48GB allocated to TrueNAS VM
  - Remaining for Proxmox + other VMs
- **Storage:**
  - Internal: 5x 8TB LFF (TrueNAS, H330 passthrough)
  - External: 24x SFF in DS2246 (TrueNAS, 9201-8e passthrough)
  - Local NVMe for Proxmox boot
- **Role:** TrueNAS VM (pinned) + compute workloads

**Workload Examples:**
- TrueNAS VM (storage for cluster)
- Jellyfin (media server with transcoding)
- Backup VMs
- Secondary K8s nodes

### Total Cluster Capacity

**Compute:**
- **r630:** 36C/72T (2x E5-2699 v3 @ 2.3 GHz)
- **r730xd:** 24C/48T (2x E5-2680 v3 @ 2.5 GHz)
- **Total vCPU:** 60 cores / 120 threads
- **RAM:** 192-320GB DDR4 ECC total (64-128GB r630 + 128-192GB r730xd)
- **Storage:** 5x 8TB LFF + 24x SFF via TrueNAS (DS2246)
- **GPU:** Intel Arc A310 Eco (4GB, AV1 transcode)

**Use Cases Supported:**
- Multiple K8s clusters simultaneously
- OpenShift + K8s + spare capacity
- Karpenter node scaling simulations
- Jellyfin + hardware transcoding (Arc A310)
- Light LLM inference (4GB VRAM)

## E5-2600 v3 CPU Pricing (January 2026)

German market via eBay.de including international sellers shipping to Germany.

| Model | Cores | Threads | Base GHz | TDP | Best Price € | Source |
|-------|-------|---------|----------|-----|--------------|--------|
| E5-2620 v3 | 6 | 12 | 2.4 | 85W | €8 | eBay intl |
| E5-2630 v3 | 8 | 16 | 2.4 | 85W | €10 | Bytestock/eBay |
| E5-2640 v3 | 8 | 16 | 2.6 | 90W | €12 | eBay intl |
| E5-2650 v3 | 10 | 20 | 2.3 | 105W | €12 | eBay intl |
| E5-2660 v3 | 10 | 20 | 2.6 | 105W | €15 | eBay intl |
| E5-2670 v3 | 12 | 24 | 2.3 | 120W | €12 | eBay intl |
| E5-2680 v3 | 12 | 24 | 2.5 | 120W | €18 | Bytestock |
| E5-2690 v3 | 12 | 24 | 2.6 | 135W | €12 | Bytestock |
| E5-2697 v3 | 14 | 28 | 2.6 | 145W | €18 | Bytestock |
| E5-2698 v3 | 16 | 32 | 2.3 | 135W | €30 | eBay intl |
| **E5-2699 v3** | **18** | **36** | **2.3** | **145W** | **€36-40** | **Poland ✓** |

### Sourcing Notes

- **Best value:** E5-2699 v3 @ €36-40 (18C flagship for lowest price)
- **User verified:** Screenshot confirmed €39.99 (€35.99 with coupon) from Poland, free shipping
- **Bytestock UK:** £10-75 GBP, professional refurb with 5-year warranty
- **eBay.de tip:** Sort by "Niedrigster Preis inkl. Versand" (lowest price incl. shipping)
- **Avoid:** German B2B sellers (2-3x markup for warranty)

---

## GPU Options

| GPU | VRAM | Jellyfin | Inference | Price | Form Factor | Notes |
|-----|------|----------|-----------|-------|-------------|-------|
| **Intel Arc A310 Eco** | **4GB** | **Excellent (AV1)** | **Light** | **€90-120** | **Low-profile** | **Selected for r630** |
| Intel Arc A380 | 6GB | Excellent (AV1) | Light | €120 | Full-height | Needs 2U |
| Nvidia P2000 | 5GB | Great | Light | €80-100 | Full-height | No power connector |
| Nvidia P400 | 2GB | Good | Minimal | €30-40 | Low profile | Older, no AV1 |
| GTX 1070 | 8GB | Great | Medium | €80-100 | Full-height | More VRAM |

**Selected:** Intel Arc A310 Eco @ €90-120

- **Low-profile form factor** (fits r630's 3x low-profile PCIe slots)
- AV1 hardware encode/decode (future-proof for Jellyfin)
- 4GB sufficient for transcoding workloads
- Single-slot, low power (~75W)
- PCIe 4.0 x8 interface

---

## 10GbE NIC Options

| NIC | Ports | Price | Notes |
|-----|-------|-------|-------|
| Intel X520-DA2 | 2x SFP+ | €30-50 | Widely compatible |
| Mellanox ConnectX-3 | 2x SFP+ | €25-40 | Excellent Linux support |
| **Intel X710-DA2** | **2x SFP+** | **€50-80** | **Recommended for r630/r730xd cluster** |

**Selected Configuration:**
- **r630:** Onboard 2x 10GbE SFP+ (daughter card) - no add-in NIC needed
- **r730xd:** Onboard 2x 10GbE SFP+ (or add-in Intel X710-DA2)
- Direct connection using Cisco DAC cables (SFP+ direct attach copper)
- 10GbE point-to-point link: r630 ↔ r730xd

**Benefits:**
- r630 already has onboard 2x SFP+ (saves €50-80 for add-in NIC)
- Dual ports per node enable future LACP bonding for 20Gbps aggregate
- Direct connection eliminates need for 10GbE switch (saves €150-300)
- Both ports available: one for cluster traffic, one for storage traffic (or bonded)

---

## Power Consumption & Costs

### Munich Electricity Pricing

- **Residential rate:** €0.35-0.40/kWh (all-in with taxes)
- **Used for calculations:** €0.38/kWh

### Server Power Draw (Estimated)

| Node | Idle | Typical | Max |
|------|------|---------|-----|
| r730xd (2x SSD boot, 16 LFF, TrueNAS VM, 5x drives) | 120W | 160W | 350W |
| r630 (1x SATA boot, 8 SFF, Arc A310, compute) | 100W | 150W | 320W |
| DS2246 (24x SFF drives) | 60W | 80W | 150W |
| **Total** | **280W** | **390W** | **820W** |

### Monthly Electricity Cost

| Scenario | Watts | kWh/month | €/month | €/year |
|----------|-------|-----------|---------|--------|
| Idle 24/7 | 280W | 202 kWh | €77 | €924 |
| **Typical use** | **390W** | **281 kWh** | **€107** | **€1,284** |
| Heavy load | 600W | 432 kWh | €164 | €1,968 |

**Notes:**
- DS2246 power includes 24x populated SFF drives
- Typical use assumes ~40% average load
- Heavy load includes GPU transcoding, multiple VMs under load

---

## Workload Capacity

### Lab Resource Requirements (LXC/lightweight VMs)

| Component | Lab Sizing |
|-----------|------------|
| K8s control plane node | 2 vCPU, 2-4GB RAM |
| K8s worker node | 1-2 vCPU, 2-4GB RAM |
| OpenShift control plane | 4 vCPU, 8GB RAM |
| OpenShift worker | 2 vCPU, 4-8GB RAM |

### What 60C/120T + 192-320GB RAM Can Run

- 6-10 full K8s clusters simultaneously
- Multiple OpenShift clusters + K8s + spare capacity
- Karpenter node scaling simulations with realistic worker node counts
- Dozens of learning environments in parallel
- Heavy nested virtualization workloads

### Use Cases Supported

| Use Case | Status |
|----------|--------|
| Proxmox HA cluster | ✓ (2-node, manual failover acceptable) |
| K8s multi-cluster | ✓ |
| OpenShift learning | ✓ |
| Karpenter simulation | ✓ |
| Jellyfin + transcoding | ✓ (Arc A310 Eco low-profile) |
| Light LLM inference | ✓ (4GB VRAM) |
| TrueNAS storage | ✓ (16 LFF + 24 SFF via DS2246, 10GbE) |

---

## HA Cluster & Quorum Considerations

For homelab/learning purposes, 2-node Proxmox cluster without quorum is acceptable:

- Not running production SLAs
- If a node dies, manually start VMs on surviving node
- Can add external Raspberry Pi as quorum voter later if desired
- Saves €80-300 vs adding dedicated quorum hardware

**What matters more:** Capacity for nested virtualization (K8s, OpenShift, Karpenter learning) rather than production-grade HA.

---

## Cost Summary

### r730xd (Storage + Compute)

| Component | Status | Estimated Cost |
|-----------|--------|----------------|
| R730xd chassis (16 LFF + 2 SFF) | Acquired @ €270 | €270 |
| CPUs: 2x E5-2680 v3 (12C/24T each) | To be installed | €36 (2x €18) |
| RAM: 128-192GB DDR4 ECC | To be installed | €150-250 |
| Dell H330 Mini (IT mode) | Likely included | €0-50 |
| LSI 9201-8e HBA card | To be acquired | €30-60 |
| SFF-8088 SAS cables (2x) | To be acquired | €20-40 |
| 10GbE NIC (if not onboard) | Optional | €0-80 |
| 2x SATA SSD boot drives (rear) | To be acquired | €40-80 |
| **r730xd Total** | | **€546-866** |

### r630 (Compute)

| Component | Status | Estimated Cost |
|-----------|--------|----------------|
| R630 chassis (8 SFF) | Acquired @ €100 | €100 |
| 2x E5-2699 v3 CPUs (18C/36T each) | Included in chassis | €0 |
| 64-128GB DDR4 ECC RAM | Included in chassis | €0 |
| Onboard 2x 10GbE SFP+ (NDC) | Included in chassis | €0 |
| SATA boot drive (optical bay) | To be acquired | €15-25 |
| Intel Arc A310 Eco (low-profile) | To be acquired | €90-120 |
| **r630 Total** | | **€205-245** |

### DS2246 Disk Shelf

| Component | Status | Estimated Cost |
|-----------|--------|----------------|
| DS2246 + IOM6 modules | To be acquired | €150-200 |
| 24x SFF drive trays | Likely included | €0-50 |
| 24x SFF drives | Already owned | €0 |
| **DS2246 Total** | | **€150-250** |

### Networking & Accessories

| Item | Status | Cost |
|------|--------|------|
| 2x Cisco DAC cables (SFP+, r630 ↔ r730xd) | To be acquired | €30-60 |
| Rack or shelving | To be acquired | €100-300 |
| Power strips / UPS | To be acquired | €100-250 |
| **Accessories Total** | | **€230-610** |

### Total Investment

| Category | Cost Range |
|----------|------------|
| r730xd (storage + compute) | €546-866 |
| r630 (compute) | €205-245 |
| DS2246 (disk shelf) | €150-250 |
| Accessories | €230-610 |
| **Total Hardware** | **€1,131-1,971** |

**Already Paid:** €370 (r730xd €270 + r630 €100)
**Remaining:** €761-1,601

---

## Reference Links

### Verified Sellers

- **eBay.de** - Dell server sources (Compicool, professional refurbishers)
- **Bytestock UK** - CPUs with 5-year warranty

### eBay.de Search Tips

- Sort: "Niedrigster Preis inkl. Versand"
- Include international sellers (Poland, UK ship to DE)
- Filter: "Artikelstandort: Europäische Union"

### Key Searches

- `R730xd 16LFF` - Storage chassis
- `R630` - Compute node
- `DS2246` or `NetApp disk shelf` - External storage
- `E5-2699 v3` - Flagship 18C CPU
- `LSI 9201-8e` - External HBA card
- `Intel X710-DA2` or `Mellanox ConnectX-3` - 10GbE NIC

---

## Document Info

- **Last Updated:** January 2026
- **Purpose:** r630/r730xd cluster planning reference
- **Status:** r730xd acquired (€270), remaining components to be sourced

---

## Next Steps

### Hardware Acquisition

1. **r630** - Source 1U compute node with CPUs/RAM (€310-660)
2. **DS2246** - Acquire disk shelf with IOM6 modules (€150-200)
3. **LSI 9201-8e** - External HBA for DS2246 connection (€30-60)
4. **SFF-8088 cables** - 2x for redundant paths to shelf (€20-40)
5. **10GbE connectivity** - DAC cables or verify onboard SFP+ (€0-140)

### Initial Setup

1. **r730xd Configuration:**
   - Flash H330 Mini to IT mode
   - Install LSI 9201-8e HBA
   - Update iDRAC/BIOS firmware
   - Install CPUs and RAM
   - Configure boot NVMe

2. **r630 Configuration:**
   - Update iDRAC/BIOS firmware
   - Install CPUs and RAM
   - Configure boot NVMe
   - Install 10GbE NIC if needed

3. **Network Setup:**
   - Connect r630 ↔ r730xd via 10GbE DAC
   - Configure static IPs (10.0.0.1/30 ↔ 10.0.0.2/30)
   - Connect DS2246 to r730xd via SFF-8088 cables

4. **Proxmox Cluster:**
   - Install Proxmox on both nodes
   - Create 2-node cluster
   - Enable IOMMU on r730xd for HBA passthrough
   - Deploy TrueNAS VM on r730xd (pinned)
   - Pass through H330 + LSI 9201-8e to TrueNAS VM

5. **Storage Configuration:**
   - Create ZFS pools in TrueNAS (LFF + SFF)
   - Configure NFS/iSCSI exports for Proxmox
   - Add NUT server to Pi 4b for UPS monitoring
