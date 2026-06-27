# TrueNAS Pool Setup - P700 (grogu)

Complete guide for creating the ZFS pool configuration on TrueNAS SCALE (VMID 300) running on Proxmox (grogu).

## Hardware Configuration

| Component | Drives | Layout | Raw | Usable | Purpose |
| --------- | ------ | ------ | --- | ------ | ------- |
| **Proxmox OS** | 2× 256GB NVMe | Mirror | — | — | Hypervisor boot (includes Talos images on local-zfs) |
| **ssd** | 2× 256GB SSD | Mirror (raw disks to VM) | ~256GB | ~230GB | K8s PVCs (iSCSI/NFS), databases |
| **bulk** | 6× 7.15TB (limited by smallest) | 1× 6-drive RAIDZ2 | 42.9TB | 25.3TB | Media, photos, cold observability data |
| **scratch** | 1× 2.73TB | Single disk | 2.73TB | 2.73TB | Photo dump |
| **Total** | | | **~46TB** | **~28TB** | |

## Pre-Flight Checks

```bash
# SSH to TrueNAS VM
ssh admin@192.168.0.13

# List all available disks with identifiers (for pool creation)
midclt call disk.query | jq '.[] | {name, identifier, size, model}'

# Find 256GB SSDs by size (for ssd pool mirror)
midclt call disk.query | jq '.[] | select(.size > 200000000000 and .size < 300000000000) | {name, identifier, size, model}'

# Find 8TB drives by size (for bulk pool)
midclt call disk.query | jq '.[] | select(.size > 7000000000000 and .size < 9000000000000) | {name, identifier, size, model}'

# Find 3TB drive by size (for scratch pool)
midclt call disk.query | jq '.[] | select(.size > 2800000000000 and .size < 3200000000000) | {name, identifier, size, model}'

# Alternative: Show only unused disks (not in any pool)
midclt call disk.get_unused | jq '.[] | {name, identifier, size, model}'
```

## Pool Creation

### Step 1: Create SSD Pool (CRITICAL - Do This First)

**Kubernetes needs this immediately for PVCs and databases.**

```bash
# Create a 2-drive mirror from the 256GB SSDs (passed to the TrueNAS VM as raw disks)
# midclt call pool.create accepts device names (e.g. "sdo") not /dev/disk/by-id/ paths
# Use `midclt call disk.get_unused | jq ...` to find current device names
midclt call pool.create '{
  "name": "ssd",
  "topology": {
    "data": [
      {
        "type": "MIRROR",
        "disks": ["ssd1", "ssd2"]
      }
    ]
  },
  "encryption": false
}'
```

**Why a mirror?**

- 1-drive fault tolerance with simple, fast resilvering
- All-SSD, so no separate SLOG is needed (sync writes are already fast)
- Reads are balanced across both members

**Verify ssd pool**:

```bash
zpool status ssd
# Should show:
#   - 1 mirror vdev (2 SSDs)
#   - ~230GB usable
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

**Note**: The bulk pool has no SLOG (sequential large writes don't benefit from one).

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
# Create a single-disk pool (2.73TB) for the photo dump
# Single disk = no redundancy; it holds only reproducible/transient data
midclt call pool.create '{
  "name": "scratch",
  "topology": {
    "data": [
      {
        "type": "STRIPE",
        "disks": [
          "/dev/disk/by-id/... (2.73TB)"
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
#   - 1 single-disk vdev
#   - ONLINE status

zpool list scratch
# Expected output:
# NAME      SIZE  ALLOC   FREE  CKPOINT  EXPANDSZ   FRAG    CAP  DEDUP    HEALTH
# scratch  2.73T  1.05M  2.73T        -         -     0%     0%  1.00x    ONLINE

zfs list scratch
# Expected output:
# NAME      USED  AVAIL  REFER  MOUNTPOINT
# scratch   863K  2.68T   153K  /mnt/scratch

# Note: single 2.73TB disk, no parity (no redundancy)
```

## Post-Creation Verification

```bash
# List all pools (raw capacity)
zpool list

# Expected output:
# NAME      SIZE  ALLOC   FREE  CKPOINT  EXPANDSZ   FRAG    CAP  DEDUP    HEALTH
# bulk     42.9T  1.21G  42.9T     -         -      0%     0%   1.00x    ONLINE
# scratch  2.73T  1.05M  2.73T     -         -      0%     0%   1.00x    ONLINE
# ssd       256G    0     256G     -         -      0%     0%   1.00x    ONLINE

# List available capacity for datasets
zfs list -o name,avail,used,refer,mountpoint | grep -E "^(bulk|scratch|ssd)"

# Expected output:
# NAME      AVAIL  USED  REFER  MOUNTPOINT
# bulk      25.3T  734M   170K  /mnt/bulk
# scratch   2.68T  863K   153K  /mnt/scratch
# ssd        230G  512M   170K  /mnt/ssd

# Check scrub is configured
zpool scrub ssd
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
├── backups/{timemachine,proxmox,restic-repo}
└── archive/                           # Cold storage
```

### SSD Pool (~230GB)

```text
ssd/
└── kubernetes/
    ├── nfs-dynamic/                   # democratic-csi provisions PVCs here
    │   ├── pvc-<uuid>/                # App data (auto-created)
    │   └── pvc-<uuid>/                # Configs (auto-created)
    ├── nfs-static/                    # Static PVs (manual mounts)
    └── iscsi-zvols/                   # iSCSI zvols (databases)
        ├── <zvol-name>                # PostgreSQL (auto-created)
        └── <zvol-name>                # ClickHouse (auto-created)
```

**Note**: Talos cluster boot images are stored on Proxmox's `local-zfs`, not TrueNAS.

### Scratch Pool (~2.73TB)

```text
scratch/
├── dump/                             # Photo dump landing (rsync from rpi-pihole dumper)
└── kubernetes/
    └── nfs-dynamic/                   # democratic-csi provisions PVCs here (truenas-nfs-scratch)
        └── pvc-<uuid>/                # Ephemeral PVCs (auto-created)
```

## Storage Class Matrix

| Workload | Pool | Type | Storage Class | Access Mode | Why |
| -------- | ---- | ---- | ------------- | ----------- | --- |
| **PostgreSQL, MySQL** | ssd | iSCSI | `truenas-iscsi-fast` | ReadWriteOnce | Block storage, better IOPS |
| **Redis, databases** | ssd | iSCSI | `truenas-iscsi-fast` | ReadWriteOnce | Low latency critical |
| **Forgejo Git repos DB** | ssd | iSCSI | `truenas-iscsi-fast` | ReadWriteOnce | Critical data protection |
| **Signoz ClickHouse** | ssd | iSCSI | `truenas-iscsi-fast` | ReadWriteOnce | Time-series DB performance |
| **Shared configs** | ssd | NFS | `truenas-nfs-fast` | ReadWriteMany | Multiple pods need access |
| **App data (small)** | ssd | NFS | `truenas-nfs-fast` | ReadWriteOnce | General purpose, fast access |
| **Forgejo registry** | bulk | NFS | `truenas-nfs-bulk` | ReadWriteOnce | Large images (~500GB), read-heavy |
| **Large app data** | bulk | NFS | `truenas-nfs-bulk` | ReadWriteOnce | Non-critical, size > speed |
| **Media streaming** | bulk | NFS | Static PV | ReadOnlyMany | Manual mount `/mnt/bulk/media` |
| **Signoz cold storage** | bulk | NFS | Static PV | ReadWriteOnce | Manual mount `/mnt/bulk/signoz-cold` |
| **CI cache** | scratch | NFS | `truenas-nfs-scratch` | ReadWriteOnce | Ephemeral, rebuild on demand |
| **Build artifacts** | scratch | NFS | `truenas-nfs-scratch` | ReadWriteOnce | Temporary, purged after 7 days |

**Note**: The democratic-csi storage classes keep their `-fast` names (`truenas-iscsi-fast`,
`truenas-nfs-fast`) for backwards compatibility — they now provision on the `ssd` pool.

## Backup Strategy

### Tier 1: Local Snapshots (truenas-primary)

- **ssd/kubernetes**: Hourly (keep 24)
- **bulk/media**: Daily (keep 7)
- **bulk/photos**: Daily (keep 30)
- **scratch/***: No snapshots (reproducible photo dump)

### Tier 2: Offsite (Backblaze B2 via Restic)

Backups go straight offsite to the `svnlto-offsite-backup` B2 bucket — there is no local
backup TrueNAS or ZFS replication.

- **ssd/kubernetes**: Hourly (K8s PVCs, databases in iSCSI zvols)
- **bulk/photos**: Daily (CRITICAL - irreplaceable Immich photos)
- **bulk/music**: Daily (music library)
- **bulk/backups/proxmox**: Daily (Proxmox VM backups)
- **bulk/backups/timemachine**: Weekly (macOS backups)
- **bulk/archive**: Weekly (cold storage)
- **Exclude**: bulk/media/movies, bulk/media/tv (replaceable), scratch/* (reproducible)

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

### SSD Pool (~230GB)

- Kubernetes NFS dynamic: app configs and small PVCs
- iSCSI zvols (databases): PostgreSQL, MySQL, ClickHouse
- **Reserve**: keep ~15-20% free for COW write performance

**Why headroom matters**: ZFS performance degrades above 90% full, COW needs free space for writes.

### Bulk Pool (28.6TB)

- Kubernetes NFS dynamic: **10TB quota** (Forgejo registry ~500GB, future growth)
- Media: ~10TB (movies, music, TV, books)
- Photos (Immich): ~5TB
- Signoz cold: ~1TB
- Backups: ~2TB (timemachine, proxmox, restic staging)
- **Reserve**: **~1TB headroom (3%)** ← Tight but acceptable for large files

### Scratch Pool (~2.73TB)

- Photo dump: rsync landing from the rpi-pihole dumper
- **Reserve**: single disk, no redundancy — holds only reproducible data

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
3. ⬜ Deploy democratic-csi in Kubernetes (fast-iscsi, fast-nfs, bulk-nfs, scratch-nfs)
4. ⬜ Set up Restic offsite backup to B2 (`svnlto-offsite-backup`)

## References

- TrueNAS Ansible Setup: `docs/truenas-ansible-setup.md`
- Dataset Variables: `ansible/vars/datasets.yml`
- Snapshot Policies: `ansible/vars/snapshots.yml`
- NFS/SMB Shares: `ansible/vars/shares.yml`
- Playbook: `ansible/playbooks/truenas-setup.yml`
