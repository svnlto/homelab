# TrueNAS SCALE Ansible Automation Guide

> **Last Updated:** January 2026
> **Target:** TrueNAS SCALE 25.04+ (Fangtooth)
> **API Method:** WebSocket via `midclt` (REST API deprecated)
> **Hardware:** Dell R730xd ("din") running TrueNAS VM on Proxmox

## Executive Summary

As of TrueNAS SCALE 25.04, the REST API is **deprecated** and replaced by the WebSocket-based `midclt` tool. The **de facto standard** for Ansible automation is:

| Approach | Use Case | Maturity |
|----------|----------|----------|
| **arensb.truenas** collection | Datasets, shares, services, users | ⭐⭐⭐ Good |
| **midclt via shell tasks** | Pool creation, advanced config | ⭐⭐ Manual but reliable |
| **TrueNAS built-in tasks** | Snapshots, replication, scrubs | ⭐⭐⭐ Native |

---

## Part 0: Your Hardware Context

Based on our previous conversations:

### Current Inventory

| Component | Count | Location/Purpose |
|-----------|-------|------------------|
| **Dell R730xd** ("din") | 12× LFF front + 2× SFF rear + 4× internal | TrueNAS primary (VM on Proxmox) |
| **Dell R630** ("grogu") | Primary compute | Proxmox + Jellyfin (Arc A310) |
| **Dell MD1220** | 24× 2.5" JBOD | Attached to R730xd → fast pool |
| **Dell MD1200** | 12× 3.5" JBOD | Attached to R630 → TrueNAS backup |
| **8TB HGST Ultrastar** | 5× | R730xd front → bulk pool |
| **3TB Dell Constellation** | 8× | MD1200 → backup pool |
| **900GB 10K SAS** | 24× | MD1220 → fast pool |
| **120GB SSD** | 2× | R730xd rear SFF → SLOG |
| **256GB SATA** | 1× | R730xd PCIe → boot drive |
| **256GB NVMe** | 1× | R730xd PCIe → spare/L2ARC |
| **10G DAC** | 1× | Between R630 ↔ R730xd |

### Pool Layout

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                      R730xd "din" — PRIMARY TRUENAS                             │
└─────────────────────────────────────────────────────────────────────────────────┘

    POOL: fast (DEPLOYED)
    ═══════════════════════
    Location: MD1220 (24× 2.5" bays, 3 slots empty — drives failed during NetApp reformat)
    Drives:   21× 900GB 10K SAS + 2× 120GB Intel SSD (SLOG)
    Layout:   3× 7-drive RAIDZ2 + mirrored SLOG
    Usable:   ~14TB
    Purpose:  Primary working pool — Kubernetes, VMs, databases

        ┌─────────┐ ┌─────────┐ ┌─────────┐   ┌────────┐
        │ raidz2  │ │ raidz2  │ │ raidz2  │   │  SLOG  │
        │ 7×900GB │ │ 7×900GB │ │ 7×900GB │   │ mirror │
        └─────────┘ └─────────┘ └─────────┘   └────────┘

    Expansion: If replacement 900GB drives acquired, add to
               existing vdevs or keep as hot spares.


    POOL: bulk (6× 7.15TB — DEPLOYED)
    ══════════════════════════════════
    Location: R730xd front 12× LFF bays
    Current:  6× 7.15TB HGST Ultrastar (limited by smallest drive)
    Status:   ONLINE - 42.9TB raw, 25.3TB usable

    ┌─────────────────────────────────────────────────────────────────────┐
    │ Current Configuration: 6-drive RAIDZ2                               │
    ├─────────────────────────────────────────────────────────────────────┤
    │                                                                     │
    │     ┌─────────────────────┐                                        │
    │     │ raidz2 (6× 7.15TB)  │  → 42.9TB raw / 25.3TB usable          │
    │     └─────────────────────┘                                        │
    │                                                                     │
    │     Expansion path: Add second vdev when 5-7 more drives acquired  │
    │                                                                     │
    │     ┌─────────────────────┐ ┌─────────────────────┐                │
    │     │ raidz2 (6× 8TB)     │ │ raidz2 (5-7× 8TB)   │  → 48-64TB     │
    │     └─────────────────────┘ └─────────────────────┘                │
    │                                                                     │
    │     ✓ Start using storage immediately                              │
    │     ✓ 2-drive fault tolerance                                      │
    │     ✗ Asymmetric vdevs if second vdev differs in width             │
    └─────────────────────────────────────────────────────────────────────┘

    ┌─────────────────────────────────────────────────────────────────────┐
    │ Option B: Wait for 6th drive, then start                           │
    ├─────────────────────────────────────────────────────────────────────┤
    │                                                                     │
    │     ┌─────────────────────┐                                        │
    │     │ raidz2 (6× 8TB)     │  → 32TB usable                         │
    │     └─────────────────────┘                                        │
    │                                                                     │
    │     Expansion path: Add matching 6-drive vdev (fills 12× LFF)      │
    │                                                                     │
    │     ┌─────────────────────┐ ┌─────────────────────┐                │
    │     │ raidz2 (6× 8TB)     │ │ raidz2 (6× 8TB)     │  → 64TB        │
    │     └─────────────────────┘ └─────────────────────┘                │
    │                                                                     │
    │     ✓ Clean symmetric vdevs                                        │
    │     ✓ Fills R730xd 12× LFF perfectly                               │
    │     ✗ Need to acquire 1 more 8TB first                             │
    └─────────────────────────────────────────────────────────────────────┘

    R730xd internal 4× LFF: Keep empty for future expansion beyond 12 drives


    SPECIAL VDEVS
    ═════════════
    Boot:   256GB SATA (PCIe card)
    SLOG:   2× 120GB SSD mirror (R730xd rear SFF bays) — for bulk pool sync
    L2ARC:  256GB NVMe available (skip unless needed — 10K SAS is fast)


┌─────────────────────────────────────────────────────────────────────────────────┐
│                      R630 "grogu" — BACKUP TRUENAS                              │
└─────────────────────────────────────────────────────────────────────────────────┘

    POOL: backup (READY NOW)
    ═════════════════════════
    Location: MD1200 (12× 3.5" bays)
    Current:  8× 3TB Dell Constellation

    Start now:
    ┌─────────────────────────┐
    │ raidz2 (8× 3TB)         │  → 18TB usable
    └─────────────────────────┘

    Expansion: If 18× 3TB lot won from eBay auction
    ┌─────────────────────────────────┐
    │ raidz2 (12× 3TB) — fill MD1200  │  → 30TB usable
    └─────────────────────────────────┘
    + 6× 3TB as spares (or sell)
    + 8× Constellation as cold spares or sell

    Purpose: ZFS replication target from din

    Replication flow:
    ┌──────────┐    ZFS send/recv    ┌──────────┐
    │   din    │ ─────────────────▶  │  grogu   │
    │ (primary)│      10G DAC        │ (backup) │
    │  bulk/   │                     │  backup/ │
    │  fast/   │                     │          │
    └──────────┘                     └──────────┘
```

### Recommended Starting Configuration

| Pool | Drives | Layout | Raw | Usable | Status |
|------|--------|--------|-----|--------|--------|
| **fast** | 21× 900GB 10K SAS | 3× RAIDZ2 (7-wide) + SLOG | ~17.1TB | ~14TB | Deployed |
| **bulk** | 6× 7.15TB | 1× RAIDZ2 (6-wide) | 42.9TB | 25.3TB | Ready now |
| **scratch** | 6× 2.73TB | 1× RAIDZ1 (6-wide) | 16.4TB | 12.9TB | Ready now |
| SLOG | 2× 120GB SSD | Mirror | — | — | Attached to fast pool |
| Boot | 1× 256GB SATA | Single | — | — | Already configured |

### Future Expansion Notes

**Bulk pool (8TB drives):**
- 6 drives → 32TB (single 6-wide RAIDZ2)
- 12 drives → 64TB (two 6-wide RAIDZ2 vdevs, fills R730xd front)
- 16 drives → 85TB (use internal 4× LFF for third vdev)

**Fast pool (1.2TB SAS 2.5" if acquired):**
- Keep as hot spares for MD1220
- Or gradually replace 900GB drives as they fail/age
- Do NOT mix 900GB and 1.2TB in same vdev (wastes capacity)

**Backup pool (3TB drives):**
- If 18× 3TB lot won: rebuild as 12-wide RAIDZ2 (30TB), keep spares
- Constellation drives become cold spares or resale

---

## Part 1: Dataset Hierarchy Design

```
bulk/                               # 6× 7.15TB RAIDZ2 (25.3TB usable) - media & backups
├── media/
│   ├── music/                      # → Navidrome
│   ├── movies/                     # → Jellyfin
│   ├── tv/                         # → Jellyfin
│   └── downloads/
│       ├── incomplete/             # Torrent staging
│       └── complete/               # Finished downloads
├── backups/
│   ├── timemachine/                # macOS Time Machine
│   ├── proxmox/                    # PBS datastore
│   └── restic-repo/                # Offsite staging
└── archive/                        # Cold storage

fast/                               # 10K SAS drives - hot data
├── kubernetes/
│   ├── nfs-dynamic/                # democratic-csi provisions here
│   └── nfs-static/                 # Manual PVs (configs, DBs)
├── vms/
│   └── proxmox-datastore/          # VM disk images (optional)
└── databases/                      # PostgreSQL, etc.
```

---

## Part 2: ZFS Properties by Dataset

```yaml
# vars/datasets.yml
datasets:
  # ═══════════════════════════════════════════════════════════════════
  # BULK POOL (8TB HGST) - Large sequential files
  # ═══════════════════════════════════════════════════════════════════

  bulk_media:
    recordsize: "1M"          # Large sequential reads
    compression: "lz4"
    sync: "standard"
    atime: "off"
    children:
      - music
      - movies
      - tv
      - downloads/incomplete
      - downloads/complete

  bulk_downloads_incomplete:
    recordsize: "16K"         # Torrent random writes
    compression: "off"
    sync: "disabled"

  bulk_backups_timemachine:
    recordsize: "1M"
    compression: "zstd"
    sync: "standard"
    quota: "2T"               # Per-Mac via SMB

  bulk_backups_proxmox:
    recordsize: "1M"
    compression: "zstd"
    sync: "standard"

  bulk_backups_restic:
    recordsize: "128K"
    compression: "off"        # Restic handles own compression
    sync: "standard"

  # ═══════════════════════════════════════════════════════════════════
  # FAST POOL (10K SAS) - Hot data, databases, VMs
  # ═══════════════════════════════════════════════════════════════════

  fast_kubernetes_dynamic:
    recordsize: "16K"         # Mixed workloads, DBs
    compression: "lz4"
    sync: "standard"
    quota: "100G"

  fast_kubernetes_static:
    recordsize: "128K"
    compression: "lz4"
    sync: "standard"

  fast_databases:
    recordsize: "8K"          # PostgreSQL/MySQL optimal
    compression: "lz4"
    sync: "always"            # Data integrity critical
    logbias: "latency"

  fast_vms:
    recordsize: "64K"         # VM disk images
    compression: "lz4"
    sync: "standard"
```

---

## Part 3: Snapshot & Backup Strategy

### Snapshot Retention

```yaml
# vars/snapshots.yml
snapshot_policies:
  # Bulk pool - media is replaceable, backups less frequent
  bulk_media:
    hourly: 0
    daily: 7
    weekly: 4
    monthly: 3

  bulk_backups:
    daily: 7
    weekly: 4
    monthly: 6

  # Fast pool - critical data, aggressive snapshots
  fast_kubernetes:
    hourly: 24
    daily: 7
    weekly: 4
    monthly: 6

  fast_databases:
    hourly: 48          # 2 days of hourly
    daily: 14
    weekly: 8
    monthly: 12
```

### 3-2-1 Backup Strategy

| Tier | What | Where | Tool |
|------|------|-------|------|
| **1** | Local snapshots | din (primary TrueNAS) | Built-in periodic tasks |
| **2** | Local replication | grogu (backup TrueNAS via MD1200) | ZFS send/recv over 10G |
| **3** | Cloud backup | Backblaze B2 | Restic (~€5-10/month) |

### Replication: din → grogu

```yaml
# Replication targets (TrueNAS built-in or midclt)
replication_tasks:
  - source: bulk/media
    destination: backup/media
    schedule: daily 02:00
    recursive: true

  - source: fast/kubernetes
    destination: backup/kubernetes
    schedule: hourly
    recursive: true

  - source: fast/databases
    destination: backup/databases
    schedule: "*/15 * * * *"  # Every 15 min
    recursive: true
```

The 10G DAC between din and grogu makes ZFS replication fast — this is your "warm" backup that's instantly accessible if din dies.

### What Actually Needs Cloud Backup

| Data | Size | Priority | Method |
|------|------|----------|--------|
| `fast/kubernetes/nfs-static` | ~1-10 GB | **Critical** | Restic to B2 |
| *arr databases | ~500 MB | **Critical** | Include in above |
| Navidrome DB | ~100 MB | **Critical** | Include in above |
| Proxmox configs (not VMs) | ~100 MB | **High** | Include in above |
| `bulk/media/*` | 10+ TB | **Skip** | Re-download if lost |
| `bulk/backups/timemachine` | 1+ TB | **Skip** | It IS the backup |

---

## Part 4: Ansible Implementation

### Prerequisites

```bash
# Install the collection
ansible-galaxy collection install arensb.truenas

# TrueNAS SCALE 25.04+ uses midclt natively
# No additional packages needed on TrueNAS
```

### Inventory

```yaml
# inventory/hosts.yml
all:
  children:
    truenas_primary:
      hosts:
        din:
          ansible_host: 10.0.0.10  # din's TrueNAS VM IP
          ansible_user: root
          ansible_python_interpreter: /usr/bin/python3

    truenas_backup:
      hosts:
        grogu_backup:
          ansible_host: 10.0.0.11  # grogu's backup TrueNAS IP
          ansible_user: root
          ansible_python_interpreter: /usr/bin/python3

    truenas:
      children:
        truenas_primary:
        truenas_backup:
```

### Main Playbook

```yaml
# playbooks/truenas-setup.yml
---
- name: Configure TrueNAS SCALE on din (primary)
  hosts: truenas_primary
  become: yes
  collections:
    - arensb.truenas

  vars_files:
    - ../vars/datasets.yml
    - ../vars/snapshots.yml
    - ../vars/shares.yml

  environment:
    middleware_method: client

  tasks:
    # ══════════════════════════════════════════════════════════════
    # BULK POOL DATASETS (8TB HGST drives)
    # ══════════════════════════════════════════════════════════════

    - name: Create bulk media datasets
      arensb.truenas.filesystem:
        name: "bulk/media/{{ item }}"
        state: present
        compression: lz4
        atime: "off"
      loop:
        - music
        - movies
        - tv
        - books
        - downloads
        - downloads/incomplete
        - downloads/complete

    - name: Create bulk backup datasets
      arensb.truenas.filesystem:
        name: "bulk/backups/{{ item }}"
        state: present
        compression: zstd
      loop:
        - timemachine
        - proxmox
        - restic-repo

    # ══════════════════════════════════════════════════════════════
    # FAST POOL DATASETS (10K SAS drives)
    # ══════════════════════════════════════════════════════════════

    - name: Create fast kubernetes datasets
      arensb.truenas.filesystem:
        name: "fast/kubernetes/{{ item }}"
        state: present
        compression: lz4
      loop:
        - nfs-dynamic
        - nfs-static

    - name: Create fast databases dataset
      arensb.truenas.filesystem:
        name: "fast/databases"
        state: present
        compression: lz4

    - name: Create fast vms dataset
      arensb.truenas.filesystem:
        name: "fast/vms"
        state: present
        compression: lz4

    # ══════════════════════════════════════════════════════════════
    # ADVANCED ZFS PROPERTIES (via midclt)
    # ══════════════════════════════════════════════════════════════

    - name: Set bulk/media recordsize to 1M
      ansible.builtin.command:
        cmd: >
          midclt call pool.dataset.update
          'bulk/media'
          '{"recordsize": "1M"}'
      changed_when: false

    - name: Set downloads/incomplete for torrent random writes
      ansible.builtin.command:
        cmd: >
          midclt call pool.dataset.update
          'bulk/media/downloads/incomplete'
          '{"recordsize": "16K", "compression": "OFF", "sync": "DISABLED"}'
      changed_when: false

    - name: Set fast/kubernetes/nfs-dynamic for mixed workloads
      ansible.builtin.command:
        cmd: >
          midclt call pool.dataset.update
          'fast/kubernetes/nfs-dynamic'
          '{"recordsize": "16K"}'
      changed_when: false

    - name: Set fast/databases for PostgreSQL
      ansible.builtin.command:
        cmd: >
          midclt call pool.dataset.update
          'fast/databases'
          '{"recordsize": "8K", "sync": "ALWAYS"}'
      changed_when: false

    # ══════════════════════════════════════════════════════════════
    # NFS SHARES (for Kubernetes on grogu)
    # ══════════════════════════════════════════════════════════════

    - name: Configure NFS service
      arensb.truenas.nfs:
        servers: 4
        udp: false
        v4: true

    - name: Enable NFS service
      arensb.truenas.service:
        name: nfs
        state: started
        enabled: true

    - name: Create NFS share for media (ReadOnlyMany)
      arensb.truenas.sharing_nfs:
        path: /mnt/bulk/media
        comment: "Media for Jellyfin/Navidrome on grogu"
        mapall_user: media
        mapall_group: media
        networks:
          - 10.0.0.0/24        # Cluster network
        state: present

    - name: Create NFS share for kubernetes dynamic
      arensb.truenas.sharing_nfs:
        path: /mnt/fast/kubernetes/nfs-dynamic
        comment: "democratic-csi dynamic provisioning"
        maproot_user: root
        maproot_group: wheel
        networks:
          - 10.0.0.0/24
        state: present

    - name: Create NFS share for kubernetes static
      arensb.truenas.sharing_nfs:
        path: /mnt/fast/kubernetes/nfs-static
        comment: "Static PVs for configs"
        maproot_user: root
        maproot_group: wheel
        networks:
          - 10.0.0.0/24
        state: present

    # ══════════════════════════════════════════════════════════════
    # SMB SHARES (for Time Machine from Mac)
    # ══════════════════════════════════════════════════════════════

    - name: Enable SMB service
      arensb.truenas.service:
        name: cifs
        state: started
        enabled: true

    - name: Create Time Machine SMB share
      arensb.truenas.sharing_smb:
        name: TimeMachine
        path: /mnt/bulk/backups/timemachine
        purpose: TIMEMACHINE
        comment: "macOS Time Machine backups"
        state: present

    # ══════════════════════════════════════════════════════════════
    # USERS & GROUPS
    # ══════════════════════════════════════════════════════════════

    - name: Create media group
      arensb.truenas.group:
        name: media
        gid: 1000

    - name: Create media user
      arensb.truenas.user:
        name: media
        uid: 1000
        group: media
        home: /nonexistent
        shell: /usr/sbin/nologin

    # ══════════════════════════════════════════════════════════════
    # SNAPSHOT TASKS
    # ══════════════════════════════════════════════════════════════

    - name: Create snapshot task for fast/kubernetes (hourly, keep 24)
      ansible.builtin.command:
        cmd: >
          midclt call pool.snapshottask.create '{
            "dataset": "fast/kubernetes",
            "recursive": true,
            "lifetime_value": 24,
            "lifetime_unit": "HOUR",
            "naming_schema": "auto-%Y-%m-%d_%H-%M",
            "schedule": {
              "minute": "0",
              "hour": "*",
              "dom": "*",
              "month": "*",
              "dow": "*"
            },
            "enabled": true
          }'
      register: snapshot_task
      changed_when: "'id' in snapshot_task.stdout"
      failed_when: false

    - name: Create snapshot task for fast/databases (hourly, keep 48)
      ansible.builtin.command:
        cmd: >
          midclt call pool.snapshottask.create '{
            "dataset": "fast/databases",
            "recursive": true,
            "lifetime_value": 48,
            "lifetime_unit": "HOUR",
            "naming_schema": "auto-%Y-%m-%d_%H-%M",
            "schedule": {
              "minute": "0",
              "hour": "*",
              "dom": "*",
              "month": "*",
              "dow": "*"
            },
            "enabled": true
          }'
      register: snapshot_db
      changed_when: "'id' in snapshot_db.stdout"
      failed_when: false

    - name: Create snapshot task for bulk/media (daily, keep 7)
      ansible.builtin.command:
        cmd: >
          midclt call pool.snapshottask.create '{
            "dataset": "bulk/media",
            "recursive": true,
            "lifetime_value": 7,
            "lifetime_unit": "DAY",
            "naming_schema": "daily-%Y-%m-%d",
            "schedule": {
              "minute": "0",
              "hour": "2",
              "dom": "*",
              "month": "*",
              "dow": "*"
            },
            "enabled": true
          }'
      register: snapshot_media
      changed_when: "'id' in snapshot_media.stdout"
      failed_when: false

    # ══════════════════════════════════════════════════════════════
    # SCRUB TASKS
    # ══════════════════════════════════════════════════════════════

    - name: Configure weekly scrub for bulk pool
      arensb.truenas.pool_scrub_task:
        pool: bulk
        threshold: 35
        description: "Weekly scrub - bulk"
        schedule:
          minute: "0"
          hour: "0"
          dom: "*"
          month: "*"
          dow: "sun"
        enabled: true

    - name: Configure weekly scrub for fast pool
      arensb.truenas.pool_scrub_task:
        pool: fast
        threshold: 35
        description: "Weekly scrub - fast"
        schedule:
          minute: "0"
          hour: "3"
          dom: "*"
          month: "*"
          dow: "sun"
        enabled: true

    # ══════════════════════════════════════════════════════════════
    # S.M.A.R.T. MONITORING
    # ══════════════════════════════════════════════════════════════

    - name: Enable SMART service
      arensb.truenas.service:
        name: smartd
        state: started
        enabled: true

    - name: Configure SMART
      arensb.truenas.smart:
        interval: 30
        powermode: NEVER
        critical: 10
        difference: 20
        informational: 35

    - name: Schedule weekly SMART short test
      arensb.truenas.smart_test_task:
        type: SHORT
        disks: []
        schedule:
          hour: "2"
          dom: "*"
          month: "*"
          dow: "sat"

    - name: Schedule monthly SMART long test
      arensb.truenas.smart_test_task:
        type: LONG
        disks: []
        schedule:
          hour: "3"
          dom: "1"
          month: "*"
          dow: "*"
```

---

## Part 5: Pool Creation (Manual/midclt)

The `arensb.truenas` collection doesn't cover pool creation. Here's how to create your pools via midclt:

### Get Available Disks

```bash
# List all disks with details
midclt call disk.query | jq '.[] | {name, serial, size, model}'

# Filter by size (find 8TB drives)
midclt call disk.query | jq '.[] | select(.size > 7000000000000) | {name, serial}'

# Filter by size (find 900GB drives)
midclt call disk.query | jq '.[] | select(.size > 800000000000 and .size < 1000000000000) | {name, serial}'
```

### Fast Pool (21× 900GB 10K SAS in MD1220) — DEPLOYED

```bash
# Create 3× 7-drive RAIDZ2 vdevs + mirrored SLOG (~14TB usable)
# Note: Originally 24 drives, 3 failed during NetApp 520→512 byte sector reformatting
# midclt call pool.create accepts device names (e.g. "sdo") not /dev/disk/by-id/ paths
midclt call pool.create '{
  "name": "fast",
  "topology": {
    "data": [
      {"type": "RAIDZ2", "disks": ["disk1", "disk2", "disk3", "disk4", "disk5", "disk6", "disk7"]},
      {"type": "RAIDZ2", "disks": ["disk8", "disk9", "disk10", "disk11", "disk12", "disk13", "disk14"]},
      {"type": "RAIDZ2", "disks": ["disk15", "disk16", "disk17", "disk18", "disk19", "disk20", "disk21"]}
    ],
    "log": [
      {"type": "MIRROR", "disks": ["ssd1", "ssd2"]}
    ]
  }
}'
```

### Bulk Pool — 6× 7.15TB RAIDZ2 (DEPLOYED)

```bash
# Create single 6-drive RAIDZ2 vdev (42.9TB raw, 25.3TB usable)
# Note: Pool limited by smallest drive size (7.15TB)
# No SLOG needed - sequential large writes (media files)
midclt call pool.create '{
  "name": "bulk",
  "topology": {
    "data": [
      {
        "type": "RAIDZ2",
        "disks": [
          "/dev/disk/by-id/wwn-... (7.15TB #1)",
          "/dev/disk/by-id/wwn-... (7.15TB #2)",
          "/dev/disk/by-id/wwn-... (7.15TB #3)",
          "/dev/disk/by-id/wwn-... (7.15TB #4)",
          "/dev/disk/by-id/wwn-... (7.15TB #5)",
          "/dev/disk/by-id/wwn-... (7.15TB #6)"
        ]
      }
    ],
    "log": [
      {
        "type": "MIRROR",
        "disks": [
          "/dev/disk/by-id/... (120GB SSD #1)",
          "/dev/disk/by-id/... (120GB SSD #2)"
        ]
      }
    ]
  }
}'

# Later: Add second vdev when more 8TB drives acquired
midclt call pool.attach '{
  "target_vdev": "bulk",
  "new_disk": {...}
}'

# Or expand pool with new vdev
midclt call pool.update 'bulk' '{
  "topology": {
    "data": [
      {"type": "RAIDZ2", "disks": ["new-8tb-1", "new-8tb-2", "new-8tb-3", "new-8tb-4", "new-8tb-5", "new-8tb-6"]}
    ]
  }
}'
```

### Bulk Pool — Option B: Wait for 6th drive

```bash
# Create single 6-drive RAIDZ2 vdev (~32TB usable)
midclt call pool.create '{
  "name": "bulk",
  "topology": {
    "data": [
      {
        "type": "RAIDZ2",
        "disks": [
          "/dev/disk/by-id/wwn-... (8TB #1)",
          "/dev/disk/by-id/wwn-... (8TB #2)",
          "/dev/disk/by-id/wwn-... (8TB #3)",
          "/dev/disk/by-id/wwn-... (8TB #4)",
          "/dev/disk/by-id/wwn-... (8TB #5)",
          "/dev/disk/by-id/wwn-... (8TB #6)"
        ]
      }
    ],
    "log": [
      {
        "type": "MIRROR",
        "disks": [
          "/dev/disk/by-id/... (120GB SSD #1)",
          "/dev/disk/by-id/... (120GB SSD #2)"
        ]
      }
    ]
  }
}'

# Later: Add matching 6-drive vdev to reach 64TB
```

### Backup Pool on grogu (8× 3TB Constellation)

```bash
# Run on grogu TrueNAS
# Create single 8-drive RAIDZ2 vdev (~18TB usable)
midclt call pool.create '{
  "name": "backup",
  "topology": {
    "data": [
      {
        "type": "RAIDZ2",
        "disks": [
          "/dev/disk/by-id/wwn-... (3TB #1)",
          "/dev/disk/by-id/wwn-... (3TB #2)",
          "/dev/disk/by-id/wwn-... (3TB #3)",
          "/dev/disk/by-id/wwn-... (3TB #4)",
          "/dev/disk/by-id/wwn-... (3TB #5)",
          "/dev/disk/by-id/wwn-... (3TB #6)",
          "/dev/disk/by-id/wwn-... (3TB #7)",
          "/dev/disk/by-id/wwn-... (3TB #8)"
        ]
      }
    ]
  }
}'

# If 18× 3TB lot won: Destroy and recreate with 12 drives
# Or if fresh install, start directly with 12-drive RAIDZ2 (~30TB)
```

---

## Part 6: NFS Share Matrix

| Dataset | K8s Access Mode | Consumer | mapall |
|---------|-----------------|----------|--------|
| `bulk/media` | ReadOnlyMany | Jellyfin, Navidrome | media:media |
| `fast/kubernetes/nfs-dynamic` | ReadWriteOnce | democratic-csi | root:wheel |
| `fast/kubernetes/nfs-static` | ReadWriteMany | Shared configs | root:wheel |
| `bulk/backups/proxmox` | ReadWriteOnce | PBS on grogu | root:wheel |

---

## Part 7: Replication to Backup TrueNAS (grogu)

### SSH Key Setup

```yaml
# playbooks/setup-replication.yml
---
- name: Setup replication from din to grogu
  hosts: truenas  # din
  become: yes

  tasks:
    - name: Generate SSH keypair for replication
      ansible.builtin.command:
        cmd: midclt call keychaincredential.create '{
          "name": "replication-to-grogu",
          "type": "SSH_KEY_PAIR",
          "attributes": {}
        }'
      register: keypair
      changed_when: "'id' in keypair.stdout"
      failed_when: false

    - name: Create SSH connection to grogu
      ansible.builtin.command:
        cmd: midclt call keychaincredential.create '{
          "name": "grogu-backup",
          "type": "SSH_CREDENTIALS",
          "attributes": {
            "host": "10.0.0.11",
            "port": 22,
            "username": "root",
            "private_key": {{ keypair_id }},
            "remote_host_key": "{{ grogu_host_key }}"
          }
        }'
      when: keypair is changed
```

### Replication Tasks via midclt

```bash
# Create replication task: fast/kubernetes → backup/kubernetes (hourly)
midclt call replication.create '{
  "name": "kubernetes-to-grogu",
  "direction": "PUSH",
  "transport": "SSH",
  "ssh_credentials": <credential_id>,
  "source_datasets": ["fast/kubernetes"],
  "target_dataset": "backup/kubernetes",
  "recursive": true,
  "auto": true,
  "schedule": {
    "minute": "0",
    "hour": "*",
    "dom": "*",
    "month": "*",
    "dow": "*"
  },
  "retention_policy": "SOURCE",
  "readonly": "SET"
}'

# Create replication task: fast/databases → backup/databases (every 15 min)
midclt call replication.create '{
  "name": "databases-to-grogu",
  "direction": "PUSH",
  "transport": "SSH",
  "ssh_credentials": <credential_id>,
  "source_datasets": ["fast/databases"],
  "target_dataset": "backup/databases",
  "recursive": true,
  "auto": true,
  "schedule": {
    "minute": "*/15",
    "hour": "*",
    "dom": "*",
    "month": "*",
    "dow": "*"
  },
  "retention_policy": "SOURCE",
  "readonly": "SET"
}'

# Create replication task: bulk/media → backup/media (daily)
midclt call replication.create '{
  "name": "media-to-grogu",
  "direction": "PUSH",
  "transport": "SSH",
  "ssh_credentials": <credential_id>,
  "source_datasets": ["bulk/media"],
  "target_dataset": "backup/media",
  "recursive": true,
  "auto": true,
  "schedule": {
    "minute": "0",
    "hour": "2",
    "dom": "*",
    "month": "*",
    "dow": "*"
  },
  "retention_policy": "SOURCE",
  "readonly": "SET"
}'
```

### Query Replication Status

```bash
# List all replication tasks
midclt call replication.query

# Check replication job status
midclt call replication.run '{"id": <task_id>}'
midclt call core.get_jobs '[["method", "=", "replication.run"]]' | jq
```

---

## Part 8: Restic Cloud Backup

```yaml
# playbooks/setup-restic-backup.yml
---
- name: Setup Restic backup to B2
  hosts: truenas
  become: yes

  vars:
    restic_repo: "b2:your-bucket:/truenas"
    restic_password: "{{ vault_restic_password }}"
    b2_account_id: "{{ vault_b2_account_id }}"
    b2_account_key: "{{ vault_b2_account_key }}"

  tasks:
    - name: Install restic
      ansible.builtin.apt:
        name: restic
        state: present

    - name: Create backup script
      ansible.builtin.copy:
        dest: /root/scripts/backup-to-b2.sh
        mode: '0700'
        content: |
          #!/bin/bash
          export RESTIC_REPOSITORY="{{ restic_repo }}"
          export RESTIC_PASSWORD="{{ restic_password }}"
          export B2_ACCOUNT_ID="{{ b2_account_id }}"
          export B2_ACCOUNT_KEY="{{ b2_account_key }}"

          # Backup critical data only
          restic backup \
            /mnt/fast/kubernetes/nfs-static \
            --exclude="*.log" \
            --exclude="*.tmp" \
            --tag kubernetes \
            --tag din

          # Prune old backups
          restic forget \
            --keep-hourly 24 \
            --keep-daily 7 \
            --keep-weekly 4 \
            --keep-monthly 12 \
            --prune

    - name: Create systemd timer
      ansible.builtin.copy:
        dest: /etc/systemd/system/restic-backup.timer
        content: |
          [Unit]
          Description=Daily Restic Backup

          [Timer]
          OnCalendar=*-*-* 03:00:00
          Persistent=true

          [Install]
          WantedBy=timers.target

    - name: Create systemd service
      ansible.builtin.copy:
        dest: /etc/systemd/system/restic-backup.service
        content: |
          [Unit]
          Description=Restic Backup to B2

          [Service]
          Type=oneshot
          ExecStart=/root/scripts/backup-to-b2.sh

    - name: Enable backup timer
      ansible.builtin.systemd:
        name: restic-backup.timer
        enabled: yes
        state: started
        daemon_reload: yes
```

---

## Part 8: Directory Structure

```
truenas-ansible/
├── ansible.cfg
├── inventory/
│   └── hosts.yml
├── group_vars/
│   └── all/
│       └── ssh.yml             # SSH public keys
├── vars/
│   ├── datasets.yml
│   ├── snapshots.yml
│   └── shares.yml
├── playbooks/
│   ├── truenas-setup.yml      # Main playbook
│   ├── setup-restic-backup.yml
│   └── verify-config.yml
└── README.md
```

---

## Part 9: Useful midclt Commands

```bash
# List all API methods
midclt call api.method_lookup

# ═══════════════════════════════════════════════════════════════════
# POOL OPERATIONS
# ═══════════════════════════════════════════════════════════════════
midclt call pool.query
midclt call pool.create '{"name": "test", "topology": {...}}'
midclt call disk.query | jq '.[] | {name, serial, size}'

# ═══════════════════════════════════════════════════════════════════
# DATASET OPERATIONS
# ═══════════════════════════════════════════════════════════════════
midclt call pool.dataset.query
midclt call pool.dataset.create '{"name": "bulk/test", "type": "FILESYSTEM"}'
midclt call pool.dataset.update 'bulk/test' '{"compression": "LZ4"}'
midclt call pool.dataset.delete 'bulk/test'

# ═══════════════════════════════════════════════════════════════════
# SHARE OPERATIONS
# ═══════════════════════════════════════════════════════════════════
midclt call sharing.nfs.query
midclt call sharing.nfs.create '{"path": "/mnt/bulk/share", "comment": "test"}'
midclt call sharing.smb.query
midclt call sharing.smb.create '{"name": "share", "path": "/mnt/bulk/share"}'

# ═══════════════════════════════════════════════════════════════════
# SNAPSHOT OPERATIONS
# ═══════════════════════════════════════════════════════════════════
midclt call pool.snapshottask.query
midclt call zfs.snapshot.query '[["dataset", "=", "bulk/media"]]'

# ═══════════════════════════════════════════════════════════════════
# SERVICE OPERATIONS
# ═══════════════════════════════════════════════════════════════════
midclt call service.query
midclt call service.start 'nfs'
midclt call service.update 'nfs' '{"enable": true}'
```

---

## Part 10: Important Notes

### API Changes (2025)

- **REST API is DEPRECATED** as of TrueNAS SCALE 25.04
- Use `midclt` (WebSocket client) for all programmatic access
- WebSocket endpoint changed from `/websocket` to `/api/current`
- The `arensb.truenas` collection supports both methods

### arensb.truenas Collection Coverage

| Feature | Module | Status |
|---------|--------|--------|
| Datasets | `filesystem` | ✅ Full support |
| NFS shares | `sharing_nfs` | ✅ Full support |
| SMB shares | `sharing_smb` | ✅ Full support |
| Users/Groups | `user`, `group` | ✅ Full support |
| Services | `service` | ✅ Full support |
| Snapshots | `pool_snapshot_task` | ✅ Full support |
| Scrubs | `pool_scrub_task` | ✅ Full support |
| SMART | `smart`, `smart_test_task` | ✅ Full support |
| **Pool creation** | — | ❌ Use midclt |
| **Replication** | — | ❌ Use midclt/GUI |
| **ACLs** | — | ❌ Use midclt |

### Don't Install Packages on TrueNAS Base OS

Never install sanoid or other packages directly — use:
- Built-in snapshot/replication tasks
- Docker apps
- External systems that pull via SSH/ZFS send

---

## Quick Start

```bash
# 1. Install collection
ansible-galaxy collection install arensb.truenas

# 2. Create inventory
mkdir -p truenas-ansible/inventory
cat > truenas-ansible/inventory/hosts.yml << 'EOF'
all:
  children:
    truenas_primary:
      hosts:
        din:
          ansible_host: 10.0.0.10
          ansible_user: root
    truenas_backup:
      hosts:
        grogu_backup:
          ansible_host: 10.0.0.11
          ansible_user: root
EOF

# 3. Test connection
ansible truenas_primary -m ping -i inventory/hosts.yml
ansible truenas_backup -m ping -i inventory/hosts.yml

# 4. Run playbook (primary)
ansible-playbook playbooks/truenas-setup.yml --check  # Dry run
ansible-playbook playbooks/truenas-setup.yml          # Apply

# 5. Setup replication
ansible-playbook playbooks/setup-replication.yml
```

---

## References

- [arensb/ansible-truenas](https://github.com/arensb/ansible-truenas)
- [TrueNAS API Client (midclt)](https://github.com/truenas/api_client)
- [TrueNAS SCALE 25.04 Release Notes](https://www.truenas.com/docs/scale/25.04/gettingstarted/scalereleasenotes/)
- [democratic-csi](https://github.com/democratic-csi/democratic-csi)

---

## Changelog

| Date | Change |
|------|--------|
| 2026-01-30 | Complete pool design with current inventory: 5×8TB, 8×3TB, 24×900GB |
| 2026-01-30 | Added bulk pool expansion options (5-wide now vs wait for 6th drive) |
| 2026-01-30 | Corrected boot drive: 256GB SATA on PCIe (not SSD mirror) |
| 2026-01-30 | Added 3TB Constellation drives for backup pool on grogu |
| 2026-01 | Corrected disk shelves: MD1220 (24×2.5" on din), MD1200 (12×3.5" on grogu backup) |
| 2026-01 | Added backup TrueNAS on grogu with ZFS replication setup |
| 2026-01 | Added replication tasks via midclt |
| 2026-01 | Split inventory into truenas_primary and truenas_backup groups |
| 2026-01 | Added hardware context from past conversations (R730xd, 8TB HGST, 10K SAS) |
| 2026-01 | Split into bulk/fast pool design |
| 2025-12 | Initial version |
