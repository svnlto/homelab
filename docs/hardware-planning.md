# Homelab Hardware Planning - December 2025

## Overview

This document captures hardware research and decisions for a homelab build targeting:

- Proxmox virtualization cluster
- TrueNAS storage
- Kubernetes/OpenShift learning environments
- Karpenter node scaling simulation
- Jellyfin media server with hardware transcoding
- Occasional LLM inference

## Platform Comparison: Workstation vs Server

### Lenovo ThinkStation P500/P510 (Workstation Path)

#### Platform Specifications

| Feature | P500 | P510 |
|---------|------|------|
| Socket | LGA 2011-3 | LGA 2011-3 |
| CPU Support | E5-1600/2600 v3 | E5-1600/2600 v3/v4 |
| RAM Type | DDR4 ECC RDIMM | DDR4 ECC RDIMM |
| RAM Slots | 8 | 8 |
| Max RAM | 256GB (8x32GB) | 256GB (8x32GB) |
| PCIe Slots | 2x x16, 1x x4, 1x x1 | 2x x16, 1x x4, 1x x1 |
| **PCIe Bifurcation** | **No** (needs PLX card) | **Yes** (BIOS option) |
| Native M.2 | Yes (1 slot on motherboard) | Yes (1 slot on motherboard) |
| Internal Drive Bays | 4x 3.5" + 1x 5.25" | 4x 3.5" + 1x 5.25" |
| Max Drives | 6-8 with adapters/5.25" cage | 6-8 with adapters/5.25" cage |
| Form Factor | Tower | Tower |
| Noise Level | Quiet (25-35 dB) | Quiet (25-35 dB) |
| Idle Power | ~60-80W | ~60-80W |
| Typical Power | ~90-120W | ~90-120W |

#### P500 vs P510 Key Difference

**PCIe Bifurcation:**

- **P510:** Native BIOS support - can split x16 slot to 4x4 for quad NVMe cards
- **P500:** No native bifurcation - requires PLX switch card (~€50-80) for NVMe expansion

**CPU Support:**

- **P510:** Supports both v3 AND v4 Xeons (Broadwell = more efficient)
- **P500:** v3 only (Haswell)

**Recommendation:** P510 if available at similar price; P500 perfectly adequate if not doing heavy NVMe expansion.

#### P500/P510 Pricing (eBay.de/Kleinanzeigen - December 2025)

| Configuration | Price Range |
|---------------|-------------|
| P500 barebones (no CPU/RAM) | €80-150 |
| P500 with E5-1620 v3, 16GB | €150-200 |
| P500 with E5-2680 v3, 32GB | €200-300 |
| P510 (generally €30-50 more) | €150-350 |

#### P500/P510 Advantages

- ✓ Tower form factor = desk-friendly, no rack needed
- ✓ Quiet operation (25-35 dB) - designed for office use
- ✓ Native M.2 NVMe boot slot
- ✓ DDR4 ECC support (same as servers)
- ✓ E5 v3/v4 CPU compatibility (same as servers)
- ✓ Lower power consumption than 2U servers
- ✓ All components transfer to server hardware later

#### P500/P510 Limitations

- ✗ P500 lacks PCIe bifurcation (P510 has it)
- ✗ Limited to 4-6 internal drive bays (vs 12+ in servers)
- ✗ No hot-swap capability
- ✗ No remote management (no iDRAC/iLO equivalent)
- ✗ No redundant PSU
- ✗ 10GbE requires add-in NIC

#### Three-Node P500 HA Cluster (Original Design)

Early in research, a 3-node P500 HA cluster was evaluated:

| Node | Role | Config |
|------|------|--------|
| Node 1 | Proxmox + Compute | E5-2699 v3, 64GB, NVMe boot |
| Node 2 | Proxmox + Compute | E5-2699 v3, 64GB, NVMe boot |
| Node 3 | TrueNAS + Quorum | E5-2660 v3, 64GB, 4x HDD |

**10GbE Networking:** 3x Intel X520 or Mellanox ConnectX-3

**Total Cost Estimate:** €1,000-1,400 for 3 nodes

**Why this was set aside:** Server hardware (R730xd) proved cheaper with more features (hot-swap, iDRAC, 10GbE included).

---

### Dell R730/R730xd (Server Path)

#### Platform Specifications

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

#### Server Advantages

- ✓ 12 or 24 hot-swap drive bays
- ✓ iDRAC 8 Enterprise (remote console, power, monitoring)
- ✓ Redundant PSUs included
- ✓ ReadyRails for proper rack mounting
- ✓ PCIe bifurcation native in BIOS
- ✓ Some R730xd include 10GbE onboard
- ✓ Higher density (2x nodes in 4U)
- ✓ Often cheaper than workstations at equivalent specs

#### Server Disadvantages

- ✗ 20-50W higher idle power (~€500/year extra at Munich rates)
- ✗ Louder (35-50 dB vs 25-35 dB)
- ✗ Requires rack or sturdy shelf
- ✗ Deep chassis (750mm+) needs proper rack depth
- ✗ Not suitable for noise-sensitive living spaces

---

## Phased Acquisition Strategy

### Phase 1: Munich Studio (6+ months)

**Constraint:** Noise-sensitive shared living space (studio apartment)

**Hardware:** 1-2x Lenovo P500/P510 workstations

**Why P500/P510 for studio:**

- Tower form factor sits on/under desk
- Quiet operation (25-35 dB) won't disturb flatmates/neighbors
- No rack infrastructure needed
- Lower power = lower electricity bill during tight budget period
- Can run full Proxmox + K8s learning environment

**P500 Economics (essentially "renting"):**

| | Cost |
|--|------|
| Buy P500 with basic config | €150-250 |
| Sell after 6-12 months | €100-180 |
| **Net "rental" cost** | **€50-100** |

### Phase 2: Own Apartment

**Hardware:** Dell R730xd + R730 rack servers

**Why servers for own space:**

- Can isolate noise in separate room/closet
- Hot-swap bays for easy drive management
- iDRAC for remote management
- Higher density in proper 12U+ rack
- Better value per compute/storage unit

### Component Transferability

**Critical insight:** All major components transfer between P500 and R730 platforms with zero waste.

| Component | P500 → R730 | Notes |
|-----------|-------------|-------|
| DDR4 ECC RAM | ✓ | Same RDIMM spec |
| E5 v3/v4 CPUs | ✓ | Same LGA 2011-3 socket |
| 10GbE NIC (PCIe) | ✓ | Standard PCIe x8 card |
| GPU (PCIe) | ✓ | Standard PCIe x16 card |
| SATA drives | ✓ | Same interface |
| SAS drives | ✓ | Need HBA/RAID controller |
| NVMe drives | ✓ | PCIe-based, universal |

**Strategy:** Buy CPU, RAM, GPU, NIC now → use in P500 → transfer to R730 later.

### What to Buy When

**Buy Now (deals expire, use in P500):**

- [ ] R730xd 12LFF @ €179 (Compicool) - store until apartment
- [ ] E5-2699 v3 @ €36-40 (Poland seller) - use in P500
- [ ] Arc A380 @ €120 - use in P500
- [ ] 10GbE NIC @ €30-50 - use in P500

**Buy for Studio Phase:**

- [ ] P500/P510 workstation (€150-250)
- [ ] RAM if not included (€60-100 for 64GB)
- [ ] NVMe boot drive (€30-50)

**Buy When Moving to Apartment:**

- [ ] R730 8SFF barebones (~€200)
- [ ] Drives (prices drop, no point storing spinning rust)
- [ ] DAC cables for 10GbE
- [ ] Rack + accessories

**Sell When Moving:**

- [ ] P500/P510 (recoup €100-180)

### Prep Work During Studio Phase

If storing R730xd while using P500:

- Flash H730P to IT mode (if using ZFS direct disk access)
- Update iDRAC and BIOS firmware
- Noctua fan swap for noise reduction (€80-100)
- Test POST with RAM/CPU before storing
- Benchmark idle power consumption
- Configure iDRAC networking

---

## Final Server Stack (Phase 2)

### Configuration: 4U Total

| Role | Hardware | Specs | Cost |
|------|----------|-------|------|
| **TrueNAS** | R730xd 12LFF | E5-2660 v4 (14C/28T), 64GB RAM | €179 |
| **Proxmox** | R730 8SFF | E5-2699 v3 (18C/36T), 64GB RAM | ~€235-290 |
| **GPU** | Intel Arc A380 | 6GB, AV1 encode/decode | €120 |
| **NIC** | Intel X520 / Mellanox ConnectX-3 | 10GbE SFP+ | €30-50 |
| **Total** | | | **€564-639** |

### Aggregate Resources

- **CPU:** 32 cores / 64 threads
- **RAM:** 128GB DDR4 ECC
- **Storage:** 12x 3.5" LFF hot-swap bays (TrueNAS) + 8x 2.5" SFF (Proxmox local)
- **Network:** 10GbE between nodes (R730xd has 2x 10GbE SFP+ onboard)
- **GPU:** 6GB VRAM for transcoding + light inference

---

## Reference Server Deal: R730xd 12LFF

**Source:** eBay.de - Compicool (professional refurbisher)
**Price:** €179
**Verified:** December 2025

### Included in €179

| Component | Spec | Standalone Value |
|-----------|------|------------------|
| Chassis | R730xd 12x 3.5" LFF | €150-250 |
| CPU | E5-2660 v4 (14C/28T, 2.0GHz) | €25-40 |
| RAID Controller | H730P Mini (2GB cache) | €40-80 |
| Network | 2x 10GbE SFP+ onboard | €50-80 |
| PSU | 2x 750W redundant | €20-40 |
| Rails | Dell ReadyRails | €40-80 |
| Caddies | 12x LFF (per images) | €60-120 |
| Management | iDRAC 8 Enterprise | included |
| **Total Value** | | **€385-690** |
| **Actual Price** | | **€179** |

### To Add

- RAM: Reuse existing 64GB DDR4 ECC
- Drives: 12x LFF SATA/SAS (as needed)
- DAC cables: €15-30 for 10GbE connectivity

---

## E5-2600 v3 CPU Pricing (December 2025)

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

| GPU | VRAM | Jellyfin | Inference | Price | Notes |
|-----|------|----------|-----------|-------|-------|
| Intel Arc A380 | 6GB | Excellent (AV1) | Light | €120 | **Recommended** |
| Nvidia P2000 | 5GB | Great | Light | €80-100 | No power connector |
| Nvidia P400 | 2GB | Good | Minimal | €30-40 | Low profile |
| GTX 1070 | 8GB | Great | Medium | €80-100 | More VRAM |
| RTX 3060 | 12GB | Excellent | Good (7B models) | €150-200 | Auction pricing |

**Selected:** Intel Arc A380 @ €120

- AV1 hardware encode/decode (future-proof for Jellyfin)
- 6GB sufficient for light inference
- Low power (~75W)

---

## 10GbE NIC Options

| NIC | Ports | Price | Notes |
|-----|-------|-------|-------|
| Intel X520-DA2 | 2x SFP+ | €30-50 | Widely compatible |
| Mellanox ConnectX-3 | 2x SFP+ | €25-40 | Excellent Linux support |
| Intel X710-DA2 | 2x SFP+ | €50-80 | Newer, better features |

**Note:** R730xd already includes 2x 10GbE SFP+ onboard - only need NIC for R730 Proxmox node.

---

## Power Consumption & Costs

### Munich Electricity Pricing

- **Residential rate:** €0.35-0.40/kWh (all-in with taxes)
- **Used for calculations:** €0.38/kWh

### Server Power Draw

| Node | Idle | Typical | Max |
|------|------|---------|-----|
| R730xd (TrueNAS, 12 HDDs) | 120W | 150W | 300W |
| R730 (Proxmox, GPU) | 100W | 180W | 400W |
| **Total** | **220W** | **330W** | **700W** |

### Monthly Electricity Cost

| Scenario | Watts | kWh/month | €/month |
|----------|-------|-----------|---------|
| Idle 24/7 | 220W | 158 kWh | €60 |
| **Typical use** | **330W** | **238 kWh** | **€90** |
| Heavy load | 500W | 360 kWh | €137 |

### Comparison: Servers vs Workstations

| Setup | Typical Power | €/month | €/year |
|-------|---------------|---------|--------|
| 2x R730/R730xd | 330W | €90 | €1,080 |
| 2x P500 | 180W | €49 | €588 |
| **Difference** | +150W | +€41 | **+€492** |

---

## Workload Capacity

### Lab Resource Requirements (LXC/lightweight VMs)

| Component | Lab Sizing |
|-----------|------------|
| K8s control plane node | 2 vCPU, 2-4GB RAM |
| K8s worker node | 1-2 vCPU, 2-4GB RAM |
| OpenShift control plane | 4 vCPU, 8GB RAM |
| OpenShift worker | 2 vCPU, 4-8GB RAM |

### What 32C/64T + 128GB RAM Can Run

- 4-6 full K8s clusters simultaneously
- OpenShift + K8s + spare capacity
- Karpenter node scaling simulations
- Multiple learning environments in parallel

### Use Cases Supported

| Use Case | Status |
|----------|--------|
| Proxmox HA cluster | ✓ (2-node, manual failover acceptable) |
| K8s multi-cluster | ✓ |
| OpenShift learning | ✓ |
| Karpenter simulation | ✓ |
| Jellyfin + transcoding | ✓ (Arc A380) |
| Light LLM inference | ✓ (6GB VRAM) |
| TrueNAS storage | ✓ (12 LFF bays, 10GbE) |

---

## HA Cluster & Quorum Considerations

### Original Thought: M920q Tiny for Quorum

Initially considered adding Lenovo M920q Tiny nodes (€80-150 each) as lightweight Proxmox quorum voters for proper HA.

**Problem:** At €149, you can buy an R630 with 2x E5-2618L + 32GB RAM - actual compute capacity, same price as a "tiebreaker" Tiny.

### Quorum Options Evaluated

| Option | Cost | Pros | Cons |
|--------|------|------|------|
| 2x M920q Tiny | €160-300 | Small, quiet | Overpaying for just tiebreaker |
| 3rd R630/R730 | €100-180 | Full compute node | Overkill for quorum only |
| Raspberry Pi 4/5 | €50-80 | External Corosync voter | Requires separate network config |
| **2-node, no quorum** | **€0** | Simple, cheap | Manual failover required |

### Decision: 2-Node Without Quorum

For homelab/learning purposes, 2-node Proxmox cluster without quorum is acceptable:

- Not running production SLAs
- If a node dies, manually start VMs on surviving node
- Can add external Pi quorum voter later if desired (user has 4x Pis available)
- Saves €80-300 vs adding dedicated quorum hardware

**What matters more:** Capacity for nested virtualization (K8s, OpenShift, Karpenter learning) rather than production-grade HA.

---

## Acquisition Strategy

### Buy Now (deals don't last)

- [ ] R730xd 12LFF @ €179 (Compicool)
- [ ] E5-2699 v3 @ €36-40 (Poland seller)
- [ ] Arc A380 @ €120

### Buy When Moving to Own Space

- [ ] R730 8SFF barebones
- [ ] 10GbE NIC
- [ ] Drives (prices drop, no point storing)
- [ ] DAC cables
- [ ] Rack + accessories

### Prep Work While in Studio

If storing R730xd during studio phase:

- Flash H730P to IT mode (if using ZFS direct)
- Update iDRAC/BIOS firmware
- Noctua fan swap for noise reduction
- Test POST with RAM/CPU
- Benchmark idle power consumption
- Configure iDRAC networking

---

## Additional Server Options

### Dell R630 (1U Alternative)

| Feature | R630 |
|---------|------|
| Form Factor | 1U Rack |
| Sockets | 2x LGA 2011-3 |
| Drive Bays | 8x or 10x SFF (2.5") |
| Hot-Swap | Yes |
| Noise | Louder than 2U (smaller fans = higher RPM) |
| GPU Support | **Low-profile only** (no full-height cards) |
| Best For | Compute-dense nodes without GPU |

**R630 Deal Found (December 2025):** €149 from eBay.de

- Included: 2x E5-2618L v3 (8C each = 16C/32T total), 32GB RAM, H330 Mini
- Missing: 6 of 8 drive caddies (~€30-50 to complete)
- PSU: 1x only (no redundancy)

**Use Case:** Good for additional Proxmox compute node if GPU not needed in that node.

---

## Cost Summary

### P500 Studio Build (Phase 1)

| Component | Cost |
|-----------|------|
| P500 workstation (basic config) | €150-250 |
| CPU upgrade: E5-2699 v3 | €36-40 |
| RAM: 64GB DDR4 ECC (if needed) | €60-100 |
| GPU: Intel Arc A380 | €120 |
| 10GbE NIC: X520/ConnectX-3 | €30-50 |
| Boot: NVMe M.2 (256GB+) | €30-50 |
| **P500 Total** | **€426-590** |

### Server Stack (Phase 2)

| Item | Cost |
|------|------|
| R730xd 12LFF (TrueNAS) | €179 |
| R730 8SFF barebones (Proxmox) | €199-229 |
| E5-2699 v3 (already purchased) | (transfers from P500) |
| Intel Arc A380 (already purchased) | (transfers from P500) |
| 10GbE NIC (already purchased) | (transfers from P500) |
| DAC cables | €15-30 |
| **Server Hardware Total** | **€393-438** |
| Monthly power (typical) | €90 |
| **Year 1 Server Operating Cost** | **€1,080** |

### Total Investment Path

| Phase | Item | Cost |
|-------|------|------|
| Now | P500 + transferable components | €426-590 |
| Now | R730xd (buy & store) | €179 |
| **Subtotal (upfront)** | | **€605-769** |
| Later | R730 barebones | €199-229 |
| Later | DAC cables, drives, rack | varies |
| Recoup | Sell P500 | -€100-180 |
| **Net Hardware Investment** | | **€704-818 + drives/rack** |

### P500 Bridge Economics

| | Amount |
|--|--------|
| P500 purchase | €150-250 |
| P500 resale (6-12 months later) | -€100-180 |
| **Net "rental" cost** | **€50-100** |

The P500 effectively costs €50-100 to "rent" for the studio period, then all purchased components (CPU, GPU, NIC, drives) transfer to server hardware.

---

## Reference Links

### Verified Sellers

- **Compicool** (eBay.de) - Professional server refurbisher, R730xd source
- **Bytestock UK** - CPUs with 5-year warranty

### eBay.de Search Tips

- Sort: "Niedrigster Preis inkl. Versand"
- Include international sellers (Poland, UK ship to DE)
- Filter: "Artikelstandort: Europäische Union"

### Key Searches

- `R730xd 12LFF` - Storage chassis
- `R730 8SFF barebones` - Compute chassis
- `E5-2699 v3` - Flagship 18C CPU
- `Intel Arc A380` - GPU
- `Mellanox ConnectX-3` or `Intel X520` - 10GbE NIC

---

## Pricing Research Lessons Learned

During this research, initial price estimates were corrected based on user-provided screenshots and verification:

| Item | Initial Estimate | Actual Price | Error Source |
|------|------------------|--------------|--------------|
| E5-2699 v3 | €60-110 | **€36-40** | Missed Poland/intl sellers |
| R730xd complete | €229-350 | **€149-179** | Missed Compicool deals |
| R730 barebones | €179-229 | €179-199 | Close estimate |

### Key Sourcing Insights

1. **Include international sellers** - Poland, UK, Netherlands ship to Germany with free or cheap shipping
2. **Sort eBay.de correctly** - "Niedrigster Preis inkl. Versand" (lowest total price including shipping)
3. **Avoid German B2B sellers** - Often 2-3x markup for VAT invoice + warranty
4. **Check listing images carefully** - Caddies, rails, cables often visible even if not mentioned in text
5. **Professional refurbishers** (Compicool, Bytestock, ServerDomain) often have best complete deals
6. **Coupon codes exist** - eBay.de often has €5-10 off coupons for registered users

---

## Document Info

- **Generated:** December 2025
- **Source:** Claude conversation with user
- **Purpose:** Reference for Claude Code agent homelab configuration
- **Status:** Hardware research complete, ready for acquisition

---

## Next Steps for Claude Code Agent

1. **Network Configuration**
   - 10GbE between nodes (DAC cables)
   - VLAN setup for management/storage/VM traffic
   - iDRAC network configuration

2. **TrueNAS Setup**
   - ZFS pool configuration (RAIDZ1/RAIDZ2 based on drive count)
   - NFS/SMB shares for Proxmox
   - Replication/snapshot policies

3. **Proxmox Setup**
   - Cluster configuration (2-node)
   - Storage backends (local NVMe + TrueNAS NFS)
   - GPU passthrough for Arc A380
   - Network bridge configuration

4. **Container/VM Templates**
   - K8s node template (lightweight)
   - OpenShift node template
   - Jellyfin LXC with GPU passthrough

5. **Kubernetes/OpenShift**
   - K3s or RKE2 for lightweight K8s
   - OpenShift SNO or minimal cluster
   - Karpenter configuration for node scaling simulation
