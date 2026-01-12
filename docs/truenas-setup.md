# TrueNAS SCALE Setup & Automation

> **TrueNAS SCALE 25.04+ (Fangtooth)** - WebSocket API via `midclt` (REST API deprecated)

## Quick Start

```bash
# Deploy VM
just truenas-deploy

# Manual installation (one-time)
# Open Proxmox console for VM 300, complete installer
# Set IP: 192.168.1.76/24, Gateway: 192.168.1.1, DNS: 192.168.1.2
# Access: https://192.168.1.76

# Automate configuration
ansible-playbook ansible/playbooks/truenas-setup.yml
```

## Architecture

```text
Proxmox Cluster (r630 + r730xd)
├── r730xd (Storage + Compute Node)
│   ├── TrueNAS VM (ID 300, 192.168.1.76)
│   │   ├── 32GB OS disk (virtio0)
│   │   ├── Dell H330 passthrough → 5x 8TB LFF
│   │   │   → ZFS Pool 'tank-lff' (RAIDZ1/RAIDZ2)
│   │   └── LSI 9201-8e passthrough → DS2246 (24x SFF)
│   │       → ZFS Pool 'tank-sff' (RAIDZ2/RAIDZ3)
│   └── 10GbE NIC (onboard SFP+ or add-in)
│       └── Direct connection to r630 (DAC cable)
│
├── DS2246 Disk Shelf
│   ├── 24x 2.5" SFF bays (populated)
│   ├── 2x IOM6 modules (SAS connectivity)
│   └── Connected to r730xd via SFF-8088 cables
│
└── r630 (Compute Node)
    ├── VMs/LXC (arr stack, K8s, etc.)
    └── 10GbE NIC (onboard SFP+ or add-in)
        └── Direct connection to r730xd (DAC cable)

Network Topology:
r630 ↔ r730xd: Direct 10GbE DAC connection
r730xd → DS2246: SFF-8088 SAS cables (dual-path)
```

## Network Configuration

### Physical Connection

**Hardware:**

- 2x 10GbE SFP+ NICs (onboard or add-in, one per node)
- 2x Cisco DAC cables (SFP+ direct attach copper)
- Direct connection topology (no switch required)
- 2x SFF-8088 SAS cables (r730xd to DS2246, dual-path redundancy)

**Port Assignment:**

| Node | 10GbE Storage/Cluster | 1GbE Management |
|------|----------------------|-----------------|
| r730xd | 10.0.0.1/30 | 192.168.1.76 |
| r630 | 10.0.0.2/30 | 192.168.1.XX |

### TrueNAS VM Network Configuration

**VM NIC Setup:**

```bash
# In Proxmox, configure TrueNAS VM with bridge to 10GbE interface
# Edit /etc/pve/qemu-server/300.conf
net0: virtio=XX:XX:XX:XX:XX:XX,bridge=vmbr1,firewall=1

# vmbr1 should be bridged to the 10GbE SFP+ port
```

**PCIe Passthrough Configuration:**

```bash
# On r730xd - enable IOMMU for HBA passthrough
# Edit /etc/default/grub
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt"

# Update GRUB
update-grub
reboot

# Find HBA controllers
lspci -nnk | grep -i -A 3 "sas\|raid"

# Example output:
# 01:00.0 RAID bus controller [0104]: Dell H330 Mini ...
# 03:00.0 Serial Attached SCSI controller [0107]: LSI 9201-8e ...

# Pass through both HBAs to TrueNAS VM (ID 300)
qm set 300 -hostpci0 01:00.0,pcie=1  # H330 (internal drives)
qm set 300 -hostpci1 03:00.0,pcie=1  # LSI 9201-8e (DS2246)
```

**TrueNAS Static IP:**

- Primary IP: 192.168.1.76/24 (management via standard network)
- Storage IP: 10.0.0.1/30 (dedicated NFS/iSCSI traffic to r630)

**Benefits of Direct Connection:**

- Full 10Gbps dedicated bandwidth for storage traffic
- Zero switch latency (sub-microsecond link)
- No contention with other network traffic
- Simplified network topology
- Cost savings (no 10GbE switch needed)

**Dual 10GbE Port Configuration (Recommended)**

Both r630 and r730xd have onboard 2x 10GbE SFP+ ports. Use them separately for better performance and isolation:

```bash
# r730xd (Proxmox + TrueNAS VM)
auto enp1s0f0
iface enp1s0f0 inet static
    address 10.0.0.1/30
    # Storage network (NFS/iSCSI to TrueNAS VM)

auto enp1s0f1
iface enp1s0f1 inet static
    address 10.0.1.1/30
    # Cluster network (Proxmox corosync, VM migrations)

# r630 (Proxmox)
auto enp2s0f0
iface enp2s0f0 inet static
    address 10.0.0.2/30
    # Storage network (mount TrueNAS shares)

auto enp2s0f1
iface enp2s0f1 inet static
    address 10.0.1.2/30
    # Cluster network (Proxmox corosync, VM migrations)
```

**Why Separate Networks Instead of LACP Bonding:**

- ✓ Full 10Gbps dedicated to storage (no sharing with cluster traffic)
- ✓ Full 10Gbps dedicated to cluster operations (VM migrations, corosync)
- ✓ Better isolation (storage failures don't affect cluster heartbeat)
- ✓ Simpler configuration (no bonding complexity)
- ✓ More performant for single-flow workloads (10Gbps > LACP for one VM)
- ✓ Proper network segmentation (storage vs management)

## Dataset Hierarchy

```text
tank/
├── media/                    # Large files, high compression
│   ├── music/                # → Navidrome
│   ├── movies/               # → Jellyfin
│   ├── tv/                   # → Jellyfin
│   └── downloads/
│       ├── incomplete/       # Random writes, low compression
│       └── complete/
├── kubernetes/
│   ├── nfs-dynamic/          # democratic-csi provisions here
│   └── nfs-static/           # Manual PVs (configs, DBs)
├── backups/
│   ├── timemachine/          # macOS Time Machine
│   ├── proxmox/              # PBS datastore
│   └── restic-repo/          # Cloud backup staging
├── vms/                      # iSCSI zvols for Proxmox VMs/LXC
│   ├── proxmox-vms (zvol)    # Main VM storage (1TB+) - iSCSI
│   ├── proxmox-backups (zvol)# VM backup storage (500GB) - iSCSI
│   ├── proxmox-lxc/          # LXC containers (NFS, optional)
│   └── proxmox-isos/         # ISO storage (NFS)
```

## Ansible Automation

### Install Collection

```bash
ansible-galaxy collection install arensb.truenas
```

### Example Playbook

```yaml
# ansible/playbooks/truenas-setup.yml
---
- name: Configure TrueNAS SCALE
  hosts: truenas
  become: yes
  collections:
    - arensb.truenas

  tasks:
    # Create datasets
    - name: Create media datasets
      arensb.truenas.filesystem:
        name: "tank/media/{{ item }}"
        state: present
        compression: lz4
        atime: "off"
      loop: [music, movies, tv, downloads]

    # Configure NFS
    - name: Enable NFS service
      arensb.truenas.service:
        name: nfs
        state: started
        enabled: true

    - name: Create NFS share for media
      arensb.truenas.sharing_nfs:
        path: /mnt/tank/media
        comment: "Media for arr-server"
        mapall_user: media
        mapall_group: media
        networks: ["192.168.1.0/24"]
        state: present

    # Advanced properties via midclt
    - name: Set media recordsize to 1M
      ansible.builtin.command:
        cmd: >
          midclt call pool.dataset.update
          'tank/media'
          '{"recordsize": "1M"}'
      changed_when: false

    # Snapshot tasks
    - name: Create daily snapshot task
      ansible.builtin.command:
        cmd: >
          midclt call pool.snapshottask.create '{
            "dataset": "tank/media",
            "recursive": true,
            "lifetime_value": 7,
            "lifetime_unit": "DAY",
            "naming_schema": "daily-%Y-%m-%d",
            "schedule": {"minute": "0", "hour": "2", "dom": "*", "month": "*", "dow": "*"},
            "enabled": true
          }'
      register: snapshot_task
      changed_when: "'id' in snapshot_task.stdout"
      failed_when: false
```

## ZFS Properties by Use Case

| Dataset | recordsize | volblocksize | compression | sync | Use Case |
| ------- | ---------- | ------------ | ----------- | ---- | -------- |
| media/* | 1M | — | lz4 | standard | Large sequential files |
| downloads/incomplete | 16K | — | off | disabled | Random writes (torrents) |
| kubernetes/nfs-dynamic | 16K | — | lz4 | standard | Mixed workloads |
| backups/timemachine | 1M | — | zstd | standard | macOS backups |
| backups/restic | 128K | — | off | standard | Restic (handles own compression) |
| **vms/proxmox-vms (zvol)** | — | **16K** | **lz4** | **standard** | **Proxmox VM disks (iSCSI)** |
| **vms/proxmox-backups (zvol)** | — | **16K** | **lz4** | **standard** | **VM backup storage (iSCSI)** |

**Key for zvols:**

- `volblocksize=16K` - Optimal for VM I/O patterns (matches guest FS blocks)
- Use `volblocksize=4K` if running databases with 4K pages
- Cannot be changed after zvol creation!

## Snapshot Strategy

| Dataset | Hourly | Daily | Weekly | Monthly |
| ------- | ------ | ----- | ------ | ------- |
| media | 0 | 7 | 4 | 3 |
| kubernetes | 24 | 7 | 4 | 6 |
| backups/timemachine | 0 | 3 | 2 | 0 |
| backups/proxmox | 0 | 7 | 4 | 3 |

## iSCSI Configuration for Proxmox VMs

### Create ZFS zvols for iSCSI

```bash
# SSH to TrueNAS
ssh root@192.168.1.76

# Create vms dataset
zfs create tank/vms

# Create zvols for Proxmox (block devices)
# volblocksize MUST be set at creation (cannot change later!)
zfs create -V 1T -o volblocksize=16K -o compression=lz4 tank/vms/proxmox-vms
zfs create -V 500G -o volblocksize=16K -o compression=lz4 tank/vms/proxmox-backups

# Verify
zfs list -t volume
```

### Configure iSCSI in TrueNAS GUI

**1. Enable iSCSI Service**

- Services → iSCSI → Start Automatically: ✓
- Click Start

**2. Create Portal** (Sharing → iSCSI → Portals → Add)

- Description: `Proxmox Portal`
- IP Address: `0.0.0.0` (listen on all interfaces)
- Port: `3260`

**3. Create Initiator Group** (Initiators → Add)

- Allowed Initiators: Leave empty (allow all) or add Proxmox IQN
- Description: `Proxmox Cluster`

**4. Create Auth** (Authorized Access → Add)

- Group ID: `1`
- User: `proxmox`
- Secret: Generate strong password (12+ chars)
- Peer User/Secret: Leave empty (one-way CHAP)

**5. Create Target** (Targets → Add)

- Target Name: `proxmox-storage`
- Target Alias: `Proxmox VM Storage`
- Portal Group: Select portal from step 2
- Initiator Group: Select from step 3
- Auth Method: `CHAP`
- Authentication Group: Select from step 4

**6. Create Extents** (Extents → Add)

*Extent 1: VM Storage*

- Name: `proxmox-vms-extent`
- Extent Type: `Device`
- Device: `zvol/tank/vms/proxmox-vms`
- Logical Block Size: `512` (or 4096 for 4K native)

*Extent 2: Backup Storage*

- Name: `proxmox-backups-extent`
- Extent Type: `Device`
- Device: `zvol/tank/vms/proxmox-backups`
- Logical Block Size: `512`

**7. Associate Targets** (Associated Targets → Add)

*LUN 0: VMs*

- Target: `proxmox-storage`
- LUN ID: `0`
- Extent: `proxmox-vms-extent`

*LUN 1: Backups*

- Target: `proxmox-storage`
- LUN ID: `1`
- Extent: `proxmox-backups-extent`

### Configure iSCSI in Proxmox

**Via Web GUI:**

1. **Add iSCSI Storage** (Datacenter → Storage → Add → iSCSI)
   - ID: `truenas-iscsi`
   - Portal: `192.168.1.76`
   - Target: `iqn.2005-10.org.freenas.ctl:proxmox-storage`
   - Nodes: Select both `pve-r630` and `pve-r730xd`
   - Enable: ✓

2. **Add LVM on iSCSI** (Storage → Add → LVM)
   - ID: `truenas-vms`
   - Base storage: `truenas-iscsi`
   - Base volume: Select LUN 0 (proxmox-vms)
   - Volume group: `truenas-vms-vg`
   - Content: `Disk image`, `Container`
   - Nodes: Both nodes
   - Shared: ✓

3. **Add LVM for Backups** (Storage → Add → LVM)
   - ID: `truenas-backups`
   - Base storage: `truenas-iscsi`
   - Base volume: Select LUN 1 (proxmox-backups)
   - Volume group: `truenas-backups-vg`
   - Content: `VZDump backup file`
   - Nodes: Both nodes
   - Shared: ✓

**Via CLI (alternative):**

```bash
# On Proxmox nodes
# Add iSCSI target
pvesm add iscsi truenas-iscsi \
  --portal 192.168.1.76 \
  --target iqn.2005-10.org.freenas.ctl:proxmox-storage \
  --nodes pve-r630,pve-r730xd

# Scan for LUNs
pvesm iscsiscan --portal 192.168.1.76

# Create LVM on LUN 0 (VMs)
pvesm add lvm truenas-vms \
  --vgname truenas-vms-vg \
  --base truenas-iscsi:/dev/disk/by-id/scsi-... \
  --content images,rootdir \
  --shared 1 \
  --nodes pve-r630,pve-r730xd

# Create LVM on LUN 1 (Backups)
pvesm add lvm truenas-backups \
  --vgname truenas-backups-vg \
  --base truenas-iscsi:/dev/disk/by-id/scsi-... \
  --content backup \
  --shared 1 \
  --nodes pve-r630,pve-r730xd
```

### Performance Tuning

**Network Configuration:**

```bash
# On Proxmox hosts - tune TCP for 10GbE iSCSI
cat >> /etc/sysctl.conf <<EOF
# TCP tuning for 10GbE iSCSI
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.core.netdev_max_backlog = 5000
EOF

sysctl -p
```

**Multipath (Optional for HA):**

If you have 2x 10GbE NICs:

```bash
# Install multipath on Proxmox
apt install multipath-tools

# Configure /etc/multipath.conf
cat > /etc/multipath.conf <<EOF
defaults {
    user_friendly_names yes
    find_multipaths yes
}
multipaths {
    multipath {
        wwid <your-iscsi-lun-wwid>
        alias truenas-vms
        path_grouping_policy group_by_prio
    }
}
EOF

systemctl restart multipath-tools
```

### Testing Performance

```bash
# On Proxmox - test iSCSI throughput
fio --name=seqwrite --ioengine=libaio --direct=1 \
    --bs=1M --iodepth=64 --size=10G \
    --rw=write --filename=/dev/dm-0

# Expected results on 10GbE:
# Sequential Write: 800-1,100 MB/s
# Sequential Read: 900-1,200 MB/s
# Random 4K (QD32): 40,000-80,000 IOPS
```

### Troubleshooting

**iSCSI connection issues:**

```bash
# On Proxmox - check iSCSI sessions
iscsiadm -m session

# Rescan for LUNs
iscsiadm -m session --rescan

# Check multipath status
multipath -ll
```

**TrueNAS logs:**

```bash
# On TrueNAS
tail -f /var/log/messages | grep iscsi

# Check iSCSI target status
midclt call iscsi.target.query
midclt call iscsi.extent.query
```

## LXC Container Storage Options

### Storage Backend Comparison for LXC

| Backend | Performance | Snapshots | Space Efficiency | Best For |
|---------|-------------|-----------|------------------|----------|
| **iSCSI/LVM** | Very Good | LVM snapshots | Good | Production containers |
| **NFS** | Good | ZFS snapshots | Excellent | Dev/test, many containers |
| **Local (ZFS)** | Excellent | ZFS snapshots | Excellent | Local-only, no migration |

### Option 1: LXC on iSCSI/LVM (Already Configured)

**Pros:**

- ✅ Same storage as VMs (already set up)
- ✅ Good performance
- ✅ Block-level efficiency
- ✅ Works for VM migration

**Cons:**

- ❌ LVM snapshots less flexible than ZFS
- ❌ More overhead than NFS for lightweight containers

**Already working** - Your `truenas-vms` LVM storage has `Content: Container` enabled!

```bash
# Create LXC on iSCSI storage
pct create 200 local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst \
  --storage truenas-vms \
  --rootfs truenas-vms:8
```

### Option 2: LXC on NFS (Recommended for Many Containers)

**Pros:**

- ✅ Better space efficiency (file-level dedup)
- ✅ ZFS snapshots on TrueNAS side
- ✅ Easy to backup/restore individual containers
- ✅ Lower overhead for many small containers
- ✅ Can store container templates

**Cons:**

- ❌ Slightly lower performance than block storage
- ❌ Network dependency

**Setup:**

```bash
# On TrueNAS - create NFS share for LXC
zfs create tank/vms/proxmox-lxc
zfs set recordsize=16K tank/vms/proxmox-lxc  # Match container I/O
zfs set compression=lz4 tank/vms/proxmox-lxc
zfs set atime=off tank/vms/proxmox-lxc

# Create NFS share (via TrueNAS GUI or midclt)
# Sharing → NFS → Add
# Path: /mnt/tank/vms/proxmox-lxc
# Networks: 192.168.1.0/24
# Maproot User/Group: root
```

**Add to Proxmox:**

```bash
# Via GUI: Datacenter → Storage → Add → NFS
# ID: truenas-lxc
# Server: 192.168.1.76
# Export: /mnt/tank/vms/proxmox-lxc
# Content: Container, Container template
# Nodes: pve-r630, pve-r730xd

# Or via CLI
pvesm add nfs truenas-lxc \
  --server 192.168.1.76 \
  --export /mnt/tank/vms/proxmox-lxc \
  --content rootdir,vztmpl \
  --nodes pve-r630,pve-r730xd
```

**Create LXC on NFS:**

```bash
pct create 200 local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst \
  --storage truenas-lxc \
  --rootfs truenas-lxc:8
```

### Recommended Strategy

**Use iSCSI/LVM for:**

- Production VMs
- Containers that need max performance (databases)
- Mixed VM+LXC workloads

**Use NFS for:**

- Development/test containers
- Arr stack (already using LXC on local storage)
- Container templates
- Many lightweight containers

**Hybrid Approach (Best):**

```yaml
Storage Layout:
  truenas-vms (iSCSI/LVM):     # VMs + heavy LXC
    - VM disks
    - Production databases in LXC

  truenas-lxc (NFS):           # Lightweight LXC
    - Dev/test containers
    - Microservices
    - Container templates

  truenas-backups (iSCSI/LVM): # Backups
    - vzdump backups
```

### Performance Impact

**NFS vs iSCSI for LXC:**

| Operation | NFS | iSCSI/LVM | Difference |
|-----------|-----|-----------|------------|
| Random Read | ~80-90 MB/s | ~100-120 MB/s | 15-20% slower |
| Random Write | ~60-80 MB/s | ~90-110 MB/s | 20-30% slower |
| Sequential | ~900 MB/s | ~1,000 MB/s | ~10% slower |
| Container Start | 2-3s | 1-2s | 1s slower |

**Verdict:** NFS performance is **good enough** for most LXC workloads. Use iSCSI only if you need every last bit of performance.

### Current Arr Stack Setup

Your arr stack (VM ID 200) currently uses **local LXC storage**:

```hcl
# terraform/proxmox/_arrstack.tf
disk {
  datastore_id = "local-lvm"  # Local storage
  size         = 50
}
```

**Consider migrating to TrueNAS NFS** for:

- Better snapshots (ZFS on TrueNAS)
- Shared storage (can migrate between nodes)
- Easier backups

**Migration path:**

```bash
# Create new LXC on NFS storage
pct create 201 local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst \
  --storage truenas-lxc \
  --rootfs truenas-lxc:50

# Or move existing container
pct move-volume 200 rootfs truenas-lxc
```

## Useful midclt Commands

```bash
# List datasets
midclt call pool.dataset.query

# Create dataset
midclt call pool.dataset.create '{"name": "tank/test", "type": "FILESYSTEM"}'

# Update properties
midclt call pool.dataset.update 'tank/test' '{"compression": "LZ4"}'

# List NFS shares
midclt call sharing.nfs.query

# List snapshots
midclt call zfs.snapshot.query '[["dataset", "=", "tank/media"]]'

# Service operations
midclt call service.query
midclt call service.start 'nfs'
```

## Mount NFS on arr-server

```bash
# On arr-server (192.168.1.50)
sudo apt install -y nfs-common
sudo mkdir -p /mnt/media /mnt/downloads

# Add to /etc/fstab
192.168.1.76:/mnt/tank/media      /mnt/media      nfs defaults,_netdev 0 0
192.168.1.76:/mnt/tank/downloads  /mnt/downloads  nfs defaults,_netdev 0 0

sudo mount -a
```

## Cloud Backup with Restic

```bash
# Install restic on TrueNAS
apt install restic

# Backup critical data to Backblaze B2
export RESTIC_REPOSITORY="b2:bucket-name:/truenas"
export RESTIC_PASSWORD="..."
export B2_ACCOUNT_ID="..."
export B2_ACCOUNT_KEY="..."

restic backup /mnt/tank/kubernetes/nfs-static --tag kubernetes
restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 12 --prune
```

## Collection Coverage

| Feature | Module | Status |
| ------- | ------ | ------ |
| Datasets | `arensb.truenas.filesystem` | ✅ Full |
| NFS shares | `arensb.truenas.sharing_nfs` | ✅ Full |
| SMB shares | `arensb.truenas.sharing_smb` | ✅ Full |
| Users/Groups | `arensb.truenas.user/group` | ✅ Full |
| Services | `arensb.truenas.service` | ✅ Full |
| Snapshots | `arensb.truenas.pool_snapshot_task` | ✅ Full |
| **Pool creation** | — | ❌ Use GUI or midclt |
| **ACLs** | — | ❌ Use midclt |

## Important Notes

- **REST API deprecated** as of 25.04 - use `midclt` (WebSocket client)
- **Never install packages on TrueNAS base OS** - use Docker apps or external systems
- **Time Machine quotas**: Set per-user to prevent one Mac consuming all space
- **Virtual disks**: Not protected against host failure - use cloud backup or replication

## References

- [arensb.truenas Collection](https://github.com/arensb/ansible-truenas)
- [TrueNAS SCALE Docs](https://www.truenas.com/docs/scale/)
- [democratic-csi](https://github.com/democratic-csi/democratic-csi) - K8s CSI for TrueNAS
