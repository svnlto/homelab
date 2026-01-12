# CPU Recommendations for Dell R630/R730xd Homelab - December 2025

## Overview

This document provides CPU recommendations for Dell PowerEdge R630 and R730xd servers used in homelab environments. Both platforms use LGA 2011-3 socket supporting Intel Xeon E5-2600 v3 (Haswell) and v4 (Broadwell) processors.

## Platform CPU Support Matrix

| Platform | Socket Count | v3 Support | v4 Support | Max TDP per Socket |
|----------|--------------|------------|------------|-------------------|
| **R630** | 2 | ✓ | ✓ | 145W per socket |
| **R730xd** | 2 | ✓ | ✓ | 145W per socket |

**Key Insight:** v4 CPUs offer ~10-22% better performance per watt but are generally more expensive. v3 CPUs offer better value for homelab use.

## Current Homelab Configuration

| Server | CPUs Installed | Total Cores/Threads | Role |
|--------|---------------|---------------------|------|
| **r630** | 2x E5-2699 v3 | 36C/72T @ 2.3 GHz | Pure compute + GPU |
| **r730xd** | 2x E5-2680 v3 | 24C/48T @ 2.5 GHz | Storage (TrueNAS) + compute |

**Total Cluster:** 60 cores / 120 threads

---

## E5-2600 v3 CPU Comparison (Haswell)

Sorted by core count, then price/performance value.

### High Core Count (12-18 cores) - Best for Compute Workloads

| Model | Cores | Threads | Base GHz | Turbo GHz | TDP | Price € | €/Core | Recommendation |
|-------|-------|---------|----------|-----------|-----|---------|--------|----------------|
| **E5-2699 v3** | **18** | **36** | **2.3** | **3.6** | **145W** | **€36-40** | **€2.22** | **★★★★★ Best value flagship** |
| E5-2698 v3 | 16 | 32 | 2.3 | 3.6 | 135W | €30 | €1.88 | ★★★★ Excellent value |
| E5-2697 v3 | 14 | 28 | 2.6 | 3.6 | 145W | €18 | €1.29 | ★★★★★ Best $/core |
| E5-2695 v3 | 14 | 28 | 2.3 | 3.3 | 120W | €25 | €1.79 | ★★★ Lower clocks |
| E5-2690 v3 | 12 | 24 | 2.6 | 3.5 | 135W | €12 | €1.00 | ★★★★★ Budget king |
| **E5-2680 v3** | **12** | **24** | **2.5** | **3.3** | **120W** | **€18** | **€1.50** | **★★★★ Balanced** |
| E5-2678 v3 | 12 | 24 | 2.5 | 3.3 | 120W | €15 | €1.25 | ★★★★ Good deal |
| E5-2670 v3 | 12 | 24 | 2.3 | 3.1 | 120W | €12 | €1.00 | ★★★★ Budget option |

### Medium Core Count (8-10 cores) - Balanced Workloads

| Model | Cores | Threads | Base GHz | Turbo GHz | TDP | Price € | €/Core | Recommendation |
|-------|-------|---------|----------|-----------|-----|---------|--------|----------------|
| E5-2660 v3 | 10 | 20 | 2.6 | 3.3 | 105W | €15 | €1.50 | ★★★★ Good all-rounder |
| E5-2650 v3 | 10 | 20 | 2.3 | 3.0 | 105W | €12 | €1.20 | ★★★ Budget 10-core |
| E5-2667 v3 | 8 | 16 | 3.2 | 3.6 | 135W | €25 | €3.13 | ★★ High freq, expensive |
| E5-2640 v3 | 8 | 16 | 2.6 | 3.4 | 90W | €12 | €1.50 | ★★★ Decent value |
| E5-2630 v3 | 8 | 16 | 2.4 | 3.2 | 85W | €10 | €1.25 | ★★★★ Great budget |
| E5-2623 v3 | 4 | 8 | 3.0 | 3.5 | 105W | €8 | €2.00 | ★ Low core, avoid |

### Low Power (L-series) - Storage/NAS Use

| Model | Cores | Threads | Base GHz | Turbo GHz | TDP | Price € | €/Core | Recommendation |
|-------|-------|---------|----------|-----------|-----|---------|--------|----------------|
| E5-2683 v3 | 14 | 28 | 2.0 | 3.0 | 120W | €20 | €1.43 | ★★★★ Best low-power 14C |
| E5-2650L v3 | 12 | 24 | 1.8 | 2.5 | 65W | €25 | €2.08 | ★★★ Ultra low power |
| E5-2630L v3 | 8 | 16 | 1.8 | 2.9 | 55W | €15 | €1.88 | ★★★ Good for NAS |

---

## E5-2600 v4 CPU Comparison (Broadwell)

### High Core Count (10-22 cores)

| Model | Cores | Threads | Base GHz | Turbo GHz | TDP | Price € | €/Core | vs v3 Equivalent |
|-------|-------|---------|----------|-----------|-----|---------|--------|------------------|
| E5-2699 v4 | 22 | 44 | 2.2 | 3.6 | 145W | €80-120 | €5.45 | +22% cores vs 2699 v3 |
| E5-2698 v4 | 20 | 40 | 2.2 | 3.6 | 135W | €70-100 | €5.00 | +25% cores vs 2698 v3 |
| E5-2697 v4 | 18 | 36 | 2.3 | 3.6 | 145W | €60-90 | €5.00 | +29% cores vs 2697 v3 |
| E5-2690 v4 | 14 | 28 | 2.6 | 3.5 | 135W | €40-60 | €4.29 | +17% cores vs 2690 v3 |
| E5-2680 v4 | 14 | 28 | 2.4 | 3.3 | 120W | €35-50 | €3.57 | +17% cores vs 2680 v3 |
| E5-2660 v4 | 14 | 28 | 2.0 | 3.2 | 105W | €25-40 | €2.86 | +40% cores vs 2660 v3 |

**Value Assessment:** v4 CPUs are 2-3x more expensive than v3 equivalents. Only worthwhile if:

- You need the absolute max core count (2699 v4 = 22C)
- Power efficiency is critical (better perf/watt)
- Your platform doesn't support v3 (both R630 and R730xd support both)

---

## CPU Recommendations by Use Case

### R630 Pure Compute Node (Dual Socket)

**Primary Role:** CPU-intensive workloads, Kubernetes clusters, GPU transcoding

**Recommended CPU Pairs:**

#### Maximum Compute (Multi-Cluster K8s/OpenShift)

**2x E5-2699 v3** (36C/72T total) - €72-80 total ✓ **INSTALLED**

- **Why:** Flagship value
- 72 threads = run 5-6 full K8s clusters simultaneously
- €2.22/core is unbeatable for 18C flagship
- Perfect for nested virtualization learning
- Pre-installed in current r630 configuration

#### Balanced Performance/Value

**2x E5-2690 v3** (24C/48T total) - €24 total

- **Why:** Best budget option
- 48 threads still runs 3-4 K8s clusters easily
- €1/core = incredible value
- Only €24 for dual 12C CPUs!

**2x E5-2680 v3** (24C/48T total) - €36 total

- **Why:** Higher base clocks than 2690 v3
- 2.5GHz base vs 2.6GHz = better single-thread
- Still great value at €1.50/core

#### High Single-Thread Performance

**2x E5-2667 v3** (16C/32T, 3.2GHz base) - €50 total

- **Why:** Applications needing high frequency
- 3.2GHz base + 3.6GHz turbo
- Better for workloads that don't scale to many cores
- More expensive (€3.13/core)

---

### R730xd Storage + Compute Node (Dual Socket)

**Primary Role:** TrueNAS VM (pinned) + additional compute workloads

**Recommended CPU Pairs:**

#### Balanced Storage + Compute

**2x E5-2680 v3** (24C/48T total) - €36 total ✓ **INSTALLED**

- **Why:** Perfect balance for TrueNAS + compute
- 24 threads handle ZFS operations on TrueNAS VM
- Remaining cores available for other VMs
- 2.5GHz base clock good for both storage and compute
- Excellent value at €1.50/core
- Currently installed in r730xd configuration

#### Budget Option

**2x E5-2660 v3** (20C/40T total) - €30 total

- **Why:** Still adequate for ZFS + light compute
- Lower cost than 2680 v3
- Slightly higher clock speed (2.6GHz)

#### Low Power (24/7 Operation)

**2x E5-2630L v3** (16C/32T, 55W TDP) - €30 total

- **Why:** Ultra low power for always-on storage
- 55W TDP per CPU = significant power savings
- 32 threads still adequate for ZFS
- Best for minimizing electricity costs

#### Maximum Compute Potential

**2x E5-2699 v3** (36C/72T total) - €72-80 total

- **Why:** If you need max cores beyond TrueNAS
- Overkill for storage alone, but maximizes compute capacity
- Allocate 8-12 cores to TrueNAS, rest for VMs

---

## Decision Matrix

| Workload Type | R630 CPUs | R730xd CPUs | Reasoning |
|--------------|-----------|-------------|-----------|
| Multi-cluster K8s | 2x E5-2699 v3 ✓ | 2x E5-2680 v3 ✓ | Max cores on compute, balanced on storage |
| OpenShift + K8s | 2x E5-2699 v3 ✓ | 2x E5-2680 v3 ✓ | Current optimal configuration |
| General compute | 2x E5-2690 v3 | 2x E5-2680 v3 ✓ | Best value |
| Gaming VMs | 2x E5-2667 v3 | 2x E5-2680 v3 ✓ | High single-thread on compute node |
| Storage-focused | 2x E5-2680 v3 | 2x E5-2630L v3 | Low power for 24/7 NAS |
| Mixed workload | 2x E5-2699 v3 ✓ | 2x E5-2680 v3 ✓ | Current configuration |

---

## TDP and Power Consumption

### TDP Categories

| TDP Range | Use Case | Examples |
|-----------|----------|----------|
| 55-85W | Low power NAS, always-on | E5-2630L v3, E5-2650L v3 |
| 90-120W | Balanced workloads | E5-2680 v3, E5-2690 v3, E5-2660 v4 |
| 135-145W | Max performance | E5-2699 v3, E5-2698 v3, E5-2697 v3 |

### Power Draw Estimates (Dual Socket)

| CPU Pair | Idle Power | Typical Load | Max Power |
|----------|------------|--------------| ----------|
| 2x E5-2630L v3 (55W) | ~80W | ~110W | ~150W |
| 2x E5-2680 v3 (120W) ✓ | ~90W | ~140W | ~240W |
| 2x E5-2699 v3 (145W) ✓ | ~100W | ~160W | ~290W |

**Note:** Total system power includes motherboard, RAM, drives, fans (add 30-60W baseline)

**Current Cluster Power Estimate:**

- r630 (2x E5-2699 v3): 100-160W typical, 290W max
- r730xd (2x E5-2680 v3): 90-140W typical, 240W max
- **Total:** 190-300W typical, 530W max (CPUs + platform)

---

## Pricing Summary (December 2025)

### Best Value Champions

| Metric | Winner | Price | Why |
|--------|--------|-------|-----|
| **Best €/Core** | E5-2690 v3 | €12 | €1.00/core for 12C |
| **Best Overall Value** | E5-2699 v3 ✓ | €36-40 | Flagship 18C at budget price |
| **Budget King** | E5-2630 v3 | €10 | Cheapest 8C option |
| **Low Power King** | E5-2630L v3 | €15 | 55W TDP, 8C/16T |
| **Best v4 Value** | E5-2660 v4 | €25-40 | 14C/28T, often included |
| **Balanced Choice** | E5-2680 v3 ✓ | €18 | 12C/24T, great all-rounder |

### Where to Buy

1. **eBay.de International Sellers** (Poland, UK)
   - Sort: "Niedrigster Preis inkl. Versand"
   - Filter: "Artikelstandort: Europäische Union"
   - Best prices, free shipping

2. **Bytestock UK**
   - Higher prices but 5-year warranty
   - Good for v4 CPUs

3. **Avoid:** German B2B sellers (2-3x markup for VAT invoice)

---

## Quick Decision Guide

### "What CPU should I buy?"

**R630 Pure Compute (dual socket):**

- Budget: 2x E5-2690 v3 (€24 total)
- Recommended: **2x E5-2699 v3 (€72-80 total)** ✓ INSTALLED
- High freq: 2x E5-2667 v3 (€50 total)

**R730xd Storage + Compute (dual socket):**

- Budget: 2x E5-2660 v3 (€30 total)
- Recommended: **2x E5-2680 v3 (€36 total)** ✓ INSTALLED
- Low power: 2x E5-2630L v3 (€30 total)

---

## Advanced: CPU Pairing Strategies

### Asymmetric Pairing (Cost Savings)

For dual-socket systems, you can use **different CPUs in each socket** if both are same generation (v3 or v4).

**Example: R630 on Budget**

- Socket 1: E5-2699 v3 (18C) - €36-40
- Socket 2: E5-2690 v3 (12C) - €12
- **Total: €48-52 for 30C/60T**

**Tradeoffs:**

- ✓ Saves €24-32 vs 2x E5-2699 v3
- ✗ Asymmetric NUMA topology (VMs may prefer socket 1)
- ✗ Different turbo frequencies between sockets

**Recommended:** Only if budget constrained. Performance difference minimal for most workloads.

### Matching Pairs (Recommended)

For best performance, use **identical CPUs** in both sockets:

- Symmetric NUMA domains
- Predictable performance
- Easier to reason about VM placement

**Current Configuration:** Both servers use matching CPU pairs (recommended approach)

---

## CPU Comparison Quick Reference

### Want Maximum Cores?

- Dual socket: **2x E5-2699 v3** (36C/72T) @ €72-80 ✓ INSTALLED (r630)

### Want Best Value?

- Dual socket: **2x E5-2690 v3** (24C/48T) @ €24

### Want Balanced Performance?

- Dual socket: **2x E5-2680 v3** (24C/48T) @ €36 ✓ INSTALLED (r730xd)

### Want Low Power?

- Dual socket: **2x E5-2650L v3** (24C/48T, 65W each) @ €50
- Dual socket: **2x E5-2630L v3** (16C/32T, 55W each) @ €30

### Want High Frequency?

- Dual socket: **2x E5-2667 v3** (16C/32T, 3.2GHz) @ €50

---

## Document Info

- **Generated:** December 2025
- **Pricing Source:** eBay.de international sellers, December 2025
- **Purpose:** CPU selection guide for Dell R630/R730xd homelab servers
- **Platforms:** R630, R730xd
- **Current Configuration:**
  - r630: 2x E5-2699 v3 (36C/72T)
  - r730xd: 2x E5-2680 v3 (24C/48T)

---

## Sources

- [Dell PowerEdge R630 Specifications](https://www.dell.com/support/home/en-us/product-support/product/poweredge-r630/docs)
- [Dell PowerEdge R730xd Specifications](https://www.dell.com/support/home/en-us/product-support/product/poweredge-r730xd/docs)
- [Intel ARK Database](https://ark.intel.com/) - Official CPU specifications
- eBay.de pricing research - December 2025

**Pricing Disclaimer:** Prices fluctuate. Check current eBay.de listings before purchasing. Prices shown include shipping to Germany.
