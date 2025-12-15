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
Proxmox Host
└── TrueNAS VM (ID 300, 192.168.1.76)
    ├── 32GB OS disk (virtio0)
    └── 3x 100GB data disks (scsi1-3)
        → ZFS Pool 'tank' (RAIDZ1)
```

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
└── vms/
    └── proxmox-datastore/    # Optional VM storage
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

| Dataset | recordsize | compression | sync | Use Case |
| ------- | ---------- | ----------- | ---- | -------- |
| media/* | 1M | lz4 | standard | Large sequential files |
| downloads/incomplete | 16K | off | disabled | Random writes (torrents) |
| kubernetes/nfs-dynamic | 16K | lz4 | standard | Mixed workloads |
| backups/timemachine | 1M | zstd | standard | macOS backups |
| backups/restic | 128K | off | standard | Restic (handles own compression) |

## Snapshot Strategy

| Dataset | Hourly | Daily | Weekly | Monthly |
| ------- | ------ | ----- | ------ | ------- |
| media | 0 | 7 | 4 | 3 |
| kubernetes | 24 | 7 | 4 | 6 |
| backups/timemachine | 0 | 3 | 2 | 0 |
| backups/proxmox | 0 | 7 | 4 | 3 |

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
