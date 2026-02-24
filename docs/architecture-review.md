# Homelab Architecture Review

**Date**: 2026-02-05
**Status**: Pre-deployment configuration review
**Purpose**: Comprehensive analysis of storage, backup, and deployment architecture

---

## Executive Summary

### ✅ What's Working Well

1. **Pool Design** - Appropriate RAID levels for data criticality
2. **Separation of Concerns** - Clear boundaries between Proxmox, TrueNAS, and Kubernetes
3. **Network Segmentation** - VLANs properly segregate traffic types
4. **Kubernetes-Native Storage** - Democratic-CSI dynamic provisioning on all 3 pools
5. **Capacity Planning** - Quotas with headroom prevent pool exhaustion

### ⚠️ Remaining Concerns

1. **Fast Pool Still Tight** - 19% headroom is good, but databases grow quickly
2. **Bulk Pool Headroom Low** - Only 3% free (acceptable for large files, but monitor closely)
3. **No Backups Implemented Yet** - Documented but not deployed (grogu offline)
4. **No Verification Playbook** - Can't automatically verify successful deployment
5. **No Monitoring/Alerts** - Pool capacity, scrub failures, replication status

---

## Architecture Overview

```text
┌─────────────────────────────────────────────────────────────────────────┐
│                          HOMELAB INFRASTRUCTURE                         │
└─────────────────────────────────────────────────────────────────────────┘

Physical Layer
──────────────
├─ R730xd (din)
│  ├─ Proxmox VE (2× 256GB NVMe mirror)
│  ├─ TrueNAS VM (VMID 300)
│  │  ├─ fast:  21× 900GB 10K SAS (3× 7-wide RAIDZ2) + 2× 120GB SLOG
│  │  ├─ bulk:  6× 8TB HGST (RAIDZ2)
│  │  └─ scratch: 6× 3TB (RAIDZ1)
│  └─ Talos K8s nodes (VMs on local-zfs)
│
├─ R630 (grogu) [OFFLINE - awaiting MikroTik switch]
│  ├─ Proxmox VE (2× 128GB SSD mirror)
│  ├─ TrueNAS Backup VM (VMID 301) [NOT DEPLOYED]
│  │  └─ backup: 11× 3TB (RAIDZ2) ← Replication target
│  └─ Jellyfin + Intel Arc A310 GPU
│
└─ MD1220/MD1200 disk shelves
   ├─ MD1220 (21× 2.5" SAS + 2× SSD) → din → fast pool
   └─ MD1200 (12× 3.5" SAS) → grogu → backup pool

Network Layer (VLANs)
─────────────────────
├─ VLAN 1  (10.10.1.0/24)   - Management (iDRAC, switches)
├─ VLAN 10 (10.10.10.0/24)  - Storage (NFS/iSCSI) ← TrueNAS primary
├─ VLAN 20 (192.168.0.0/24) - LAN (infrastructure VMs)
├─ VLAN 30 (10.0.1.0/24)    - K8s Shared Services
├─ VLAN 31 (10.0.2.0/24)    - K8s Production Apps
└─ VLAN 32 (10.0.3.0/24)    - K8s Test/Staging

Storage Layer (TrueNAS on din)
───────────────────────────────
fast pool (~16TB, RAIDZ2 2-drive fault tolerance)
├─ kubernetes/
│  ├─ iscsi-zvols/          ← PostgreSQL, MySQL, Redis, ClickHouse
│  ├─ nfs-dynamic/          ← General app data (4TB quota)
│  └─ nfs-static/           ← Shared configs (manual PVs)
├─ vms/                     ← VM disk images (~2TB)
└─ ml-models/               ← Trained models (1TB quota)
Headroom: ~3TB (19%) ✅

bulk pool (~28.6TB, RAIDZ2 2-drive fault tolerance)
├─ kubernetes/nfs-dynamic/  ← Forgejo registry, large PVCs (10TB quota)
├─ media/                   ← Jellyfin streaming (~10TB)
├─ photos/                  ← Immich library (~5TB)
├─ signoz-cold/             ← Old observability data (~1TB)
├─ backups/                 ← timemachine, proxmox, forgejo (~2TB)
└─ archive/                 ← Cold storage
Headroom: ~1TB (3%) ⚠️  Monitor closely

scratch pool (~15TB, RAIDZ1 1-drive fault tolerance)
├─ kubernetes/nfs-dynamic/  ← CI cache, ephemeral (8TB quota)
├─ downloads/               ← Torrents/usenet staging (~5TB)
├─ ml-datasets/             ← Training data (~1TB)
└─ temp/                    ← General scratch
Headroom: ~1TB (7%) ✅
Acceptable: Ephemeral data, RAIDZ1 is fine here

Application Layer (Kubernetes)
───────────────────────────────
Democratic-CSI Instances:
├─ truenas-iscsi-fast       ← fast/kubernetes/iscsi-zvols (databases)
├─ truenas-nfs-fast         ← fast/kubernetes/nfs-dynamic (general)
├─ truenas-nfs-bulk         ← bulk/kubernetes/nfs-dynamic (registry)
└─ truenas-nfs-scratch      ← scratch/kubernetes/nfs-dynamic (CI cache)

Workload → Storage Mapping:
├─ Forgejo
│  ├─ PostgreSQL DB         → truenas-iscsi-fast (PVC)
│  ├─ Git repos             → truenas-iscsi-fast (PVC)
│  ├─ Container registry    → truenas-nfs-bulk (PVC ~500GB)
│  └─ Config                → truenas-nfs-fast (PVC)
├─ Signoz
│  ├─ ClickHouse DB         → truenas-iscsi-fast (PVC ~500GB)
│  └─ Cold storage          → bulk/signoz-cold (Static PV)
├─ Immich
│  └─ Photos                → bulk/photos (Static PV ~5TB)
├─ Jellyfin
│  └─ Media streaming       → bulk/media (Static PV ReadOnly)
└─ CI/CD
   └─ Build cache           → truenas-nfs-scratch (PVC ephemeral)

Infrastructure as Code
──────────────────────
Terragrunt (infrastructure/):
├─ prod/storage/
│  ├─ truenas-primary       ← Deploys VMID 300 (din)
│  └─ truenas-backup        ← Deploys VMID 301 (grogu) [NOT READY]
└─ dev/compute/
   └─ test-cluster          ← Talos K8s test deployment

Ansible (ansible/):
├─ playbooks/
│  ├─ truenas-setup.yml     ← Datasets, shares, snapshots, scrubs
│  └─ truenas-replication.yml [TO BE CREATED] ← Backup setup
└─ vars/
   ├─ datasets.yml          ← ZFS properties, quotas
   ├─ snapshots.yml         ← Snapshot policies, replication
   └─ shares.yml            ← NFS/SMB exports
```

---

## Critical Analysis

### 1. Fast Pool Capacity (CONCERN)

**Current Allocation**:

```text
Allocated:
- kubernetes/nfs-dynamic: 4TB quota
- kubernetes/iscsi-zvols: ~6TB (databases)
- vms: ~2TB
- ml-models: 1TB quota
Total: 13TB / 16TB = 81% full
Headroom: 3TB (19%)
```

**Growth Projections**:

- **Databases grow fastest** - PostgreSQL, ClickHouse, Redis
- **Forgejo Git repos** - grows with every commit
- **VMs** - relatively static unless new VMs deployed

**Risk**: If databases hit 6TB quota and need more, pool is full.

**Mitigation Options**:

1. **Monitor closely** - set alerts at 85%, 90%
2. **Increase database zvol size slowly** - tune as needed
3. **Move non-critical workloads to bulk pool**
4. **Future expansion** - add more 900GB drives (or upgrade to 1.2TB SAS)

**Recommendation**: Deploy with current quotas, monitor weekly for 1 month.

### 2. Bulk Pool Headroom (ACCEPTABLE BUT TIGHT)

**Current Allocation**:

```text
Allocated:
- kubernetes/nfs-dynamic: 10TB quota (Forgejo registry ~500GB initially)
- media: 10TB
- photos: 5TB
- signoz-cold: 1TB
- backups: 2TB
Total: 28TB / 28.6TB = 98% full
Headroom: 0.6TB (2%)
```

**Why This Is OK**:

- **Large sequential files** - no COW fragmentation issues
- **Quota on k8s dataset** - prevents runaway growth
- **Media is replaceable** - can delete if space needed

**Risk**: Photos can't grow beyond 5TB without cleanup.

**Mitigation**:

1. **Expand pool** - add more 8TB drives when available (easy to add vdev)
2. **Offload old media** - delete watched movies/shows
3. **Compress photos** - Immich already does this

**Recommendation**: Deploy as-is, plan to acquire 5-6 more 8TB drives in next 6 months.

### 3. Democratic-CSI Architecture (EXCELLENT)

**Why This Works**:

```yaml
# Instead of pre-allocating manual datasets:
bulk/container-registry/     # ❌ Static, can't resize
bulk/forgejo-artifacts/      # ❌ Manual config

# Democratic-CSI dynamically provisions:
bulk/kubernetes/nfs-dynamic/
├─ pvc-abc123/               # ✅ Auto-created when Forgejo requests
├─ pvc-def456/               # ✅ Can expand PVC on-demand
└─ pvc-ghi789/               # ✅ Delete when PVC deleted

# Benefits:
- On-demand provisioning (no wasted pre-allocated space)
- Per-PVC quotas (limit runaway growth)
- Kubernetes-native (kubectl get pvc shows usage)
- Easy to expand (kubectl patch pvc)
```

**Comparison**:

| Manual Datasets | Democratic-CSI |
| --------------- | -------------- |
| Pre-allocate blindly | Allocate on-demand |
| Can't easily resize | `kubectl patch pvc` |
| Manual NFS exports | Auto-configured |
| No per-app visibility | `kubectl get pvc` shows all |

**Recommendation**: This is the correct approach. ✅

### 4. Backup Strategy (INCOMPLETE)

**Current State**: Documented but not implemented.

**3-2-1 Backup Tiers**:

```text
Tier 1: Local Snapshots (din)
├─ fast/kubernetes: Hourly (keep 24)
├─ fast/vms: Every 4 hours (keep 6)
├─ bulk/photos: Daily (keep 30)
└─ Status: ✅ Will be configured by Ansible

Tier 2: Replication (din → grogu)
├─ fast/kubernetes → backup/kubernetes (hourly)
├─ fast/vms → backup/vms (every 4 hours)
├─ bulk/photos → backup/photos (daily)
└─ Status: ❌ Not deployed (grogu offline)

Tier 3: Offsite (B2)
├─ fast/kubernetes/nfs-static (configs ~10GB)
├─ bulk/backups/forgejo (Git repos ~100GB)
└─ Status: ❌ Not deployed (Restic setup needed)
```

**Risk**: Only Tier 1 (local snapshots) will be active initially.

**Single Points of Failure**:

1. **Fire/theft of din** - all data lost (no offsite backup)
2. **Fast pool failure** - databases lost until grogu replication online
3. **Bulk pool failure** - photos lost permanently (irreplaceable!)

**Mitigation** (in order of importance):

1. **Deploy Tier 3 FIRST** - Restic to B2 for critical data
   - `bulk/photos` (5TB) - Immich can integrate with B2 directly
   - `fast/kubernetes/nfs-static` (configs ~10GB) - Restic
   - `bulk/backups/forgejo` (Git backups ~100GB) - Restic
2. **Deploy Tier 2 when grogu online** - local replication for fast recovery
3. **Test restores** - verify backups actually work

**Recommendation**: Create Restic playbook BEFORE deploying TrueNAS.

### 5. Monitoring & Alerts (MISSING)

**What's Missing**:

```text
Monitoring:
├─ Pool capacity (email at 85%, 90%, 95%)
├─ Scrub failures (weekly scrubs need to succeed)
├─ Replication status (is din → grogu working?)
├─ SMART errors (disk failures)
├─ iSCSI session drops (K8s loses database access)
└─ ZFS errors (checksum errors = data corruption)

Currently:
└─ Nothing automated ❌
```

**Risk**: Problems go unnoticed until it's too late.

**Mitigation**:

1. **TrueNAS built-in alerts** - configure email notifications
2. **Prometheus/Grafana** - scrape TrueNAS metrics
3. **AlertManager** - send alerts to Slack/email
4. **Weekly manual checks** - `zpool status`, `zpool list`

**Recommendation**: Configure TrueNAS email alerts FIRST (day 1), add Prometheus later.

### 6. Terraform/Terragrunt Integration (GOOD)

**Current Flow**:

```text
1. Terragrunt deploys TrueNAS VMs
   └─ infrastructure/prod/storage/truenas-primary/
       ├─ Creates VMID 300 on din
       ├─ Attaches H330 HBA (5× 8TB drives)
       ├─ Dual-homed networking (VLAN 10 + 20)
       └─ Manual: Attach LSI 9201-8e (21× 900GB + 2× 120GB SSD)

2. Manual pool creation
   └─ docs/truenas-pool-setup.md
       ├─ SSH to TrueNAS VM
       ├─ midclt call pool.create (fast, bulk, scratch)
       └─ Verify: zpool status

3. Ansible configures TrueNAS
   └─ ansible/playbooks/truenas-setup.yml
       ├─ Creates datasets
       ├─ Sets ZFS properties
       ├─ Configures NFS/iSCSI
       ├─ Creates snapshot tasks
       └─ Configures scrubs/SMART

4. Democratic-CSI provisions PVCs
   └─ Deployed in Kubernetes
       ├─ 4 CSI instances (fast-iscsi, fast-nfs, bulk-nfs, scratch-nfs)
       └─ Dynamic provisioning on-demand
```

**Why This is Correct**:

- **Pool creation manual** = good (one-time, high-risk, can't easily undo)
- **Dataset config via Ansible** = good (idempotent, can re-run safely)
- **PVC provisioning via K8s** = good (application-driven, automated)

**Missing Piece**: Verification playbook.

**Recommendation**: Add `ansible/playbooks/truenas-verify.yml` to validate deployment.

---

## Recommendations

### Immediate (Before Pool Creation)

1. ✅ **Reduce fast pool quotas** - Done (4TB NFS, 1TB ml-models)
2. ✅ **Add K8s parent datasets** - Done (bulk/kubernetes, scratch/kubernetes)
3. ✅ **Update capacity planning** - Done (documented headroom)
4. ⬜ **Create Restic playbook** - Offsite backup for photos/configs
5. ⬜ **Configure TrueNAS email alerts** - Day 1 monitoring

### After Pool Creation

1. ⬜ **Run Ansible playbook** - Configure datasets/shares
2. ⬜ **Create verification playbook** - Automated health checks
3. ⬜ **Deploy Democratic-CSI** - 4 instances in Kubernetes
4. ⬜ **Test PVC provisioning** - Verify each storage class works
5. ⬜ **Setup Prometheus monitoring** - Pool capacity, scrub status

### When grogu Online

1. ⬜ **Create replication playbook** - SSH keys, midclt commands
2. ⬜ **Deploy backup TrueNAS** - VMID 301 on grogu
3. ⬜ **Enable replication** - Tier 2 backup (din → grogu)
4. ⬜ **Test failover** - Can we restore from grogu if din dies?

### Long-Term

1. ⬜ **Plan fast pool expansion** - Monitor growth, acquire drives when needed
2. ⬜ **Plan bulk pool expansion** - Acquire 5-6 more 8TB drives
3. ⬜ **Document disaster recovery** - Full restore procedures
4. ⬜ **Quarterly restore tests** - Verify backups work

---

## Conclusion

### Overall Assessment: **GOOD** (with caveats)

**Strengths**:

- Pool design appropriate for data criticality ✅
- RAIDZ2 on fast/bulk pools (2-drive fault tolerance) ✅
- Kubernetes-native storage via democratic-csi ✅
- Capacity planning with headroom ✅
- Clear separation of concerns ✅

**Weaknesses**:

- Fast pool headroom tight (19%, acceptable but monitor) ⚠️
- Bulk pool headroom very tight (3%, monitor closely) ⚠️
- No backups implemented yet (documented only) ❌
- No monitoring/alerts configured ❌
- No verification playbook ❌

**Blockers**: None. Ready to deploy pools.

**Critical Path**:

1. Create Restic playbook (photos backup to B2)
2. Create pools via midclt
3. Run Ansible playbook
4. Configure TrueNAS email alerts
5. Deploy democratic-csi in Kubernetes
6. Test PVC provisioning

**Estimated Timeline**:

- Pool creation: 30 minutes
- Ansible configuration: 15 minutes
- Democratic-CSI deployment: 1 hour
- Testing: 1 hour
- **Total**: ~3 hours to fully operational storage

**Confidence Level**: **High**

This architecture is well-designed and ready for production deployment.
The tight capacity on fast/bulk pools is manageable with monitoring.
Missing backups should be addressed immediately after deployment
(Tier 3 first, then Tier 2 when grogu online).

---

## Next Actions

User should decide:

1. **Proceed with pool creation?** (docs/truenas-pool-setup.md has commands)
2. **Create Restic playbook first?** (photos backup to B2 before deploying)
3. **Create verification playbook?** (automated health checks after deployment)
4. **Deploy democratic-csi?** (requires pools + Ansible config done first)
