# TrueNAS Pool Setup - R730xd (din)

Complete guide for creating the 3-pool ZFS configuration on TrueNAS SCALE running on the R730xd.

## Hardware Configuration

| Component | Drives | Layout | Raw | Usable | Purpose |
| --------- | ------ | ------ | --- | ------ | ------- |
| **Proxmox OS** | 2× 256GB NVMe | Mirror | — | — | Hypervisor boot (includes Talos images on local-zfs) |
| **fast** | 21× 900GB + 2× 120GB SSD | 3× 7-drive RAIDZ2 + mirrored SLOG | ~17.1TB | ~14TB | K8s PVCs (iSCSI), VMs, databases, ML models |
| **bulk** | 6× 7.15TB (limited by smallest) | 1× 6-drive RAIDZ2 | 42.9TB | 25.3TB | Media, photos, cold observability data |
| **scratch** | 6× 2.73TB (limited by smallest) | 1× 6-drive RAIDZ1 | 16.4TB | 12.9TB | Downloads, CI cache, ML datasets staging |
| **Total** | | | **~76TB** | **~52TB** | |

## Pre-Flight Checks

```bash
# SSH to TrueNAS VM
ssh admin@192.168.0.13

# List all available disks with identifiers (for pool creation)
midclt call disk.query | jq '.[] | {name, identifier, size, model}'

# Find 900GB drives by size (for fast pool)
midclt call disk.query | jq '.[] | select(.size > 800000000000 and .size < 1000000000000) | {name, identifier, size, model}'

# Find 8TB drives by size (for bulk pool)
midclt call disk.query | jq '.[] | select(.size > 7000000000000 and .size < 9000000000000) | {name, identifier, size, model}'

# Find 3TB drives by size (for scratch pool)
midclt call disk.query | jq '.[] | select(.size > 2800000000000 and .size < 3200000000000) | {name, identifier, size, model}'

# Find 128GB SSD drives by size (for SLOG)
midclt call disk.query | jq '.[] | select(.size > 100000000000 and .size < 150000000000) | {name, identifier, size, model}'

# Alternative: Show only unused disks (not in any pool)
midclt call disk.get_unused | jq '.[] | {name, identifier, size, model}'
```

## Pool Creation

### Step 1: Create Fast Pool (CRITICAL - Do This First)

**Kubernetes needs this immediately for PVCs and databases.**

```bash
# Create 3× 7-drive RAIDZ2 with mirrored SLOG
# Note: Originally 24× 900GB drives, 3 failed during sector reformatting (NetApp 520→512 byte)
# midclt call pool.create accepts device names (e.g. "sdo") not /dev/disk/by-id/ paths
# Use `midclt call disk.get_unused | jq ...` to find current device names
midclt call pool.create '{
  "name": "fast",
  "topology": {
    "data": [
      {
        "type": "RAIDZ2",
        "disks": ["disk1", "disk2", "disk3", "disk4", "disk5", "disk6", "disk7"]
      },
      {
        "type": "RAIDZ2",
        "disks": ["disk8", "disk9", "disk10", "disk11", "disk12", "disk13", "disk14"]
      },
      {
        "type": "RAIDZ2",
        "disks": ["disk15", "disk16", "disk17", "disk18", "disk19", "disk20", "disk21"]
      }
    ],
    "log": [
      {
        "type": "MIRROR",
        "disks": ["ssd1", "ssd2"]
      }
    ]
  },
  "encryption": false
}'
```

**Why RAIDZ2 not RAIDZ1?**

- RAIDZ1 = only 1-drive fault tolerance (risky for critical K8s data)
- RAIDZ2 = 2-drive fault tolerance per vdev (safe for databases)
- Tradeoff: Lose capacity to parity for much better protection

**Verify fast pool**:

```bash
zpool status fast
# Should show:
#   - 3 RAIDZ2 vdevs (7 drives each)
#   - 1 mirror log vdev (2 SSDs)
#   - ~14TB usable
```

### Step 2: Create Bulk Pool

```bash
# Create 6-drive RAIDZ2 (42.9TB raw, 25.3TB usable)
# Note: Pool is limited to smallest drive size (7.15TB)
# Actual: 6× 7.15TB drives = 42.9TB raw, RAIDZ2 provides 25.3TB usable
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
    ]
  },
  "encryption": false
}'
```

**Note**: SLOG is only on fast pool (bulk pool doesn't need it - sequential large writes).

**Verify bulk pool**:

```bash
zpool status bulk
# Should show:
#   - 1 RAIDZ2 vdev (6 drives)
#   - ONLINE status

zpool list bulk
# Expected output:
# NAME   SIZE  ALLOC   FREE  CKPOINT  EXPANDSZ   FRAG    CAP  DEDUP    HEALTH
# bulk  42.9T  1.21G  42.9T        -         -     0%     0%  1.00x    ONLINE

zfs list bulk
# Expected output:
# NAME   USED  AVAIL  REFER  MOUNTPOINT
# bulk   734M  25.3T   170K  /mnt/bulk

# Note: 42.9T raw capacity, 25.3T available for datasets
# Difference accounts for RAIDZ2 parity (2 drives) + ZFS metadata overhead
```

### Step 3: Create Scratch Pool

```bash
# Create 6-drive RAIDZ1 (16.4TB raw, 12.9TB usable)
# Note: Pool is limited to smallest drive size (2.73TB)
# RAIDZ1 is OK here - ephemeral data, can be recreated
# Actual: 6× 2.73TB drives = 16.4TB raw, RAIDZ1 provides 12.9TB usable
midclt call pool.create '{
  "name": "scratch",
  "topology": {
    "data": [
      {
        "type": "RAIDZ1",
        "disks": [
          "/dev/disk/by-id/... (2.73TB #1)",
          "/dev/disk/by-id/... (2.73TB #2)",
          "/dev/disk/by-id/... (2.73TB #3)",
          "/dev/disk/by-id/... (2.73TB #4)",
          "/dev/disk/by-id/... (2.73TB #5)",
          "/dev/disk/by-id/... (2.73TB #6)"
        ]
      }
    ]
  },
  "encryption": false
}'
```

**Verify scratch pool**:

```bash
zpool status scratch
# Should show:
#   - 1 RAIDZ1 vdev (6 drives)
#   - ONLINE status

zpool list scratch
# Expected output:
# NAME      SIZE  ALLOC   FREE  CKPOINT  EXPANDSZ   FRAG    CAP  DEDUP    HEALTH
# scratch  16.4T  1.05M  16.4T        -         -     0%     0%  1.00x    ONLINE

zfs list scratch
# Expected output:
# NAME      USED  AVAIL  REFER  MOUNTPOINT
# scratch   863K  12.9T   153K  /mnt/scratch

# Note: 16.4T raw capacity, 12.9T available for datasets
# Difference accounts for RAIDZ1 parity (1 drive) + ZFS metadata overhead
```

## Post-Creation Verification

```bash
# List all pools (raw capacity)
zpool list

# Expected output:
# NAME      SIZE  ALLOC   FREE  CKPOINT  EXPANDSZ   FRAG    CAP  DEDUP    HEALTH
# bulk     42.9T  1.21G  42.9T     -         -      0%     0%   1.00x    ONLINE
# fast     17.1T    0    17.1T     -         -      0%     0%   1.00x    ONLINE
# scratch  16.4T  1.05M  16.4T     -         -      0%     0%   1.00x    ONLINE

# List available capacity for datasets
zfs list -o name,avail,used,refer,mountpoint | grep -E "^(bulk|fast|scratch)"

# Expected output:
# NAME      AVAIL  USED  REFER  MOUNTPOINT
# bulk      25.3T  734M   170K  /mnt/bulk
# fast      14.0T  512M   170K  /mnt/fast
# scratch   12.9T  863K   153K  /mnt/scratch

# Check SLOG is attached to fast pool
zpool status fast | grep log
# Should show:
#   log
#     mirror-1  ONLINE

# Check scrub is configured
zpool scrub fast
zpool scrub bulk
zpool scrub scratch
```

## Ansible Configuration

Once pools are created, run Ansible to configure datasets, shares, snapshots:

```bash
# From homelab project root
cd ansible

# Dry run (check mode)
ansible-playbook playbooks/truenas-setup.yml --check

# Apply configuration
ansible-playbook playbooks/truenas-setup.yml

# Or apply specific tags only
ansible-playbook playbooks/truenas-setup.yml --tags=datasets,properties
ansible-playbook playbooks/truenas-setup.yml --tags=nfs,iscsi
ansible-playbook playbooks/truenas-setup.yml --tags=snapshots,scrub
```

## Dataset Hierarchy Created by Ansible

### Bulk Pool (~28.6TB)

```text
bulk/
├── kubernetes/
│   └── nfs-dynamic/                   # democratic-csi provisions PVCs here
│       ├── pvc-<uuid>/                # Forgejo registry (auto-created)
│       └── pvc-<uuid>/                # Other large app data (auto-created)
├── media/{music,movies,tv,books}     # Jellyfin streaming
├── photos/                            # Immich photo library
├── signoz-cold/                       # Observability data (30+ days)
├── backups/{timemachine,proxmox,forgejo,restic-repo}
└── archive/                           # Cold storage
```

### Fast Pool (~14TB)

```text
fast/
├── kubernetes/
│   ├── nfs-dynamic/                   # democratic-csi provisions PVCs here
│   │   ├── pvc-<uuid>/                # App data (auto-created)
│   │   └── pvc-<uuid>/                # Configs (auto-created)
│   ├── nfs-static/                    # Static PVs (manual mounts)
│   └── iscsi-zvols/                   # iSCSI zvols (databases)
│       ├── <zvol-name>                # PostgreSQL (auto-created)
│       └── <zvol-name>                # ClickHouse (auto-created)
├── vms/                               # VM disk images
└── ml-models/                         # Trained ML models
```

**Note**: Talos cluster boot images are stored on Proxmox's `local-zfs`, not TrueNAS.

### Scratch Pool (~15TB)

```text
scratch/
├── kubernetes/
│   └── nfs-dynamic/                   # democratic-csi provisions PVCs here
│       └── pvc-<uuid>/                # CI cache (auto-created)
├── downloads/{incomplete,complete,usenet}  # Torrent/Usenet staging
├── ci-runners/{cache,artifacts}            # Manual NFS mounts (optional)
├── ml-datasets/                            # Training data staging
└── temp/                                   # General scratch space
```

## Storage Class Matrix

| Workload | Pool | Type | Storage Class | Access Mode | Why |
| -------- | ---- | ---- | ------------- | ----------- | --- |
| **PostgreSQL, MySQL** | fast | iSCSI | `truenas-iscsi-fast` | ReadWriteOnce | Block storage, better IOPS |
| **Redis, databases** | fast | iSCSI | `truenas-iscsi-fast` | ReadWriteOnce | Low latency critical |
| **Forgejo Git repos DB** | fast | iSCSI | `truenas-iscsi-fast` | ReadWriteOnce | Critical data protection |
| **Signoz ClickHouse** | fast | iSCSI | `truenas-iscsi-fast` | ReadWriteOnce | Time-series DB performance |
| **Shared configs** | fast | NFS | `truenas-nfs-fast` | ReadWriteMany | Multiple pods need access |
| **App data (small)** | fast | NFS | `truenas-nfs-fast` | ReadWriteOnce | General purpose, fast access |
| **Forgejo registry** | bulk | NFS | `truenas-nfs-bulk` | ReadWriteOnce | Large images (~500GB), read-heavy |
| **Large app data** | bulk | NFS | `truenas-nfs-bulk` | ReadWriteOnce | Non-critical, size > speed |
| **Media streaming** | bulk | NFS | Static PV | ReadOnlyMany | Manual mount `/mnt/bulk/media` |
| **Signoz cold storage** | bulk | NFS | Static PV | ReadWriteOnce | Manual mount `/mnt/bulk/signoz-cold` |
| **CI cache** | scratch | NFS | `truenas-nfs-scratch` | ReadWriteOnce | Ephemeral, rebuild on demand |
| **Build artifacts** | scratch | NFS | `truenas-nfs-scratch` | ReadWriteOnce | Temporary, purged after 7 days |

## Backup Strategy (3-2-1)

### Tier 1: Local Snapshots (din)

- **fast/kubernetes**: Hourly (keep 24)
- **fast/vms**: Every 4 hours (keep 6)
- **fast/ml-models**: Daily (keep 7)
- **bulk/media**: Daily (keep 7)
- **bulk/photos**: Daily (keep 30)
- **scratch/***: No snapshots (ephemeral by design)

### Tier 2: Replication (din → grogu backup pool)

- **fast/kubernetes**: Hourly
- **fast/vms**: Every 4 hours
- **fast/ml-models**: Daily
- **bulk/photos**: Daily (CRITICAL - irreplaceable)
- **bulk/signoz-cold**: Daily
- **bulk/media**: Weekly (replaceable)
- **bulk/backups**: Daily

### Tier 3: Offsite (Backblaze B2 via Restic)

- **fast/kubernetes**: Hourly (~4TB, K8s PVCs, databases in iSCSI zvols)
- **fast/vms**: Hourly (~2TB, VM disk images)
- **fast/ml-models**: Hourly (~1TB, trained models)
- **bulk/photos**: Daily (~5TB, CRITICAL - irreplaceable Immich photos)
- **bulk/music**: Daily (~10TB, music library)
- **bulk/backups/proxmox**: Daily (Proxmox VM backups)
- **bulk/backups/forgejo**: Daily (~100GB, Git repos)
- **bulk/backups/arr-configs**: Daily (arr-stack configs)
- **bulk/backups/timemachine**: Weekly (~2TB, macOS backups)
- **bulk/archive**: Weekly (cold storage)
- **Exclude**: bulk/media/movies, bulk/media/tv (replaceable), scratch/* (ephemeral)

**Estimated Offsite Cost**: ~$100-150/month (~20-30TB at $5/TB/month)

## Network Configuration

### NFS Exports (via Storage VLAN)

- **Primary**: `10.10.10.13` (Storage VLAN 10)
- **Kubernetes VLANs**: `10.0.1.0/24` (VLAN 30), `10.0.2.0/24` (VLAN 31), `10.0.3.0/24` (VLAN 32)
- **LAN**: `192.168.0.0/24` (VLAN 20) for arr-stack

### iSCSI Target

- **Portal**: `10.10.10.13:3260` (Storage VLAN only)
- **Initiator Group**: Allow `10.0.1.0/24`, `10.0.2.0/24`, `10.0.3.0/24`
- **Auth**: None (network-based access control)

## Capacity Planning

### Fast Pool (14TB) - Reduced Quotas for Headroom ✅

- Kubernetes NFS dynamic: **4TB quota** (reduced from 6TB)
- iSCSI zvols (databases): ~4TB (PostgreSQL, MySQL, ClickHouse)
- VMs: ~2TB
- ML models: **1TB quota** (reduced from 2TB)
- **Reserve**: **~3TB headroom (21%)** ← Safe margin

**Why headroom matters**: ZFS performance degrades above 90% full, COW needs free space for writes.

### Bulk Pool (28.6TB)

- Kubernetes NFS dynamic: **10TB quota** (Forgejo registry ~500GB, future growth)
- Media: ~10TB (movies, music, TV, books)
- Photos (Immich): ~5TB
- Signoz cold: ~1TB
- Backups: ~2TB (timemachine, proxmox, forgejo, restic staging)
- **Reserve**: **~1TB headroom (3%)** ← Tight but acceptable for large files

### Scratch Pool (15TB)

- Kubernetes NFS dynamic: **8TB quota** (CI cache ephemeral)
- Downloads: ~5TB (incomplete torrents, usenet staging)
- ML datasets: ~1TB
- **Reserve**: **~1TB headroom (7%)** ← Acceptable for ephemeral data

## Troubleshooting

### Pool Creation Fails

```bash
# Check if disks are already in use
zpool status
# Destroy test pools if needed
zpool destroy poolname

# Check disk availability
midclt call disk.unused
```

### SLOG Not Attached

```bash
# Add SLOG to existing pool
zpool add fast log mirror \
  /dev/disk/by-id/ssd1 \
  /dev/disk/by-id/ssd2
```

### Verify Pool Health

```bash
# Detailed status
zpool status -v

# I/O statistics
zpool iostat -v 1

# Check for errors
zpool events -v
```

## Next Steps

1. ✅ Create pools (this document)
2. ✅ Run Ansible playbook to create datasets/shares
3. ⬜ Deploy democratic-csi in Kubernetes (3 instances: fast-iscsi, fast-nfs, bulk-nfs, scratch-nfs)
4. ⬜ Configure replication to grogu backup pool
5. ⬜ Set up Restic offsite backup to B2

## References

- TrueNAS Ansible Setup: `docs/truenas-ansible-setup.md`
- Dataset Variables: `ansible/vars/datasets.yml`
- Snapshot Policies: `ansible/vars/snapshots.yml`
- NFS/SMB Shares: `ansible/vars/shares.yml`
- Playbook: `ansible/playbooks/truenas-setup.yml`
