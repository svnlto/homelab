# Proxmox Network Configuration Automation

## The Challenge

Proxmox host networking (bridges, VLAN interfaces, IP addresses) cannot be configured directly via Terraform. The bpg/terraform-provider-proxmox and Telmate providers only manage **VMs, containers, and storage** - not the underlying host network configuration.

## Solution: Terraform + Ansible

We use **Terraform to trigger Ansible playbooks** that configure Proxmox host networking.

## What Gets Configured

### Network Bridges

| Bridge | VLAN | Subnet         | Purpose                     |
|--------|------|----------------|-----------------------------|
| vmbr10 | 10   | 10.10.10.0/24  | Storage (10GbE, jumbo frames) |
| vmbr20 | 20   | 192.168.0.0/24 | LAN/Management              |
| vmbr30 | 30   | 10.0.1.0/24    | K8s Shared Services cluster |
| vmbr31 | 31   | 10.0.2.0/24    | K8s Apps cluster            |
| vmbr32 | 32   | 10.0.3.0/24    | K8s Test cluster            |

### Host IPs

**grogu (R630):**
- vmbr10: 10.10.10.10/24 (storage)
- vmbr20: 192.168.0.10/24 (management, gateway 192.168.0.1)
- vmbr30-32: No IP (VMs only)

**din (R730xd):**
- vmbr10: 10.10.10.11/24 (storage)
- vmbr20: 192.168.0.11/24 (management, gateway 192.168.0.1)
- vmbr30-32: No IP (VMs only)

## Usage

### Option 1: Direct Ansible (Recommended for first-time setup)

```bash
# Dry run (test without applying)
just proxmox-configure-networking-check

# Apply to both hosts
just proxmox-configure-networking

# Apply to single host
just proxmox-configure-networking-host grogu
```

**Manual commands:**
```bash
cd ansible

# Dry run
ansible-playbook -i inventory.ini playbooks/configure-proxmox-networking.yml --check

# Apply
ansible-playbook -i inventory.ini playbooks/configure-proxmox-networking.yml

# Single host
ansible-playbook -i inventory.ini playbooks/configure-proxmox-networking.yml --limit grogu
```

### Option 2: Via Terraform (Integrated with infrastructure deployment)

```bash
cd terraform

# Apply networking only
terraform apply -target=null_resource.proxmox_networking

# Or as part of full deployment
terraform apply
```

**What Terraform does:**
1. Waits for Proxmox hosts to be accessible (SSH port 22)
2. Triggers Ansible playbook to configure bridges
3. Shows success message with bridge configuration

### Option 3: Manual Configuration (Not Recommended)

If you prefer manual configuration:

1. **SSH into Proxmox host:**
   ```bash
   ssh root@192.168.0.10  # grogu
   ```

2. **Backup current config:**
   ```bash
   cp /etc/network/interfaces /etc/network/interfaces.backup
   ```

3. **Edit `/etc/network/interfaces`** (see template in `ansible/roles/proxmox_networking/templates/interfaces.j2`)

4. **Test configuration:**
   ```bash
   ifreload -a -s  # Dry run
   ```

5. **Apply configuration:**
   ```bash
   ifreload -a
   ```

6. **Verify bridges:**
   ```bash
   ip addr show
   brctl show
   ```

## How It Works

### Ansible Role: `proxmox_networking`

**Location:** `ansible/roles/proxmox_networking/`

**Files:**
- `tasks/main.yml` - Main configuration logic
- `templates/interfaces.j2` - /etc/network/interfaces template
- `handlers/main.yml` - Network restart handlers
- `defaults/main.yml` - Default variables

**What it does:**
1. Backs up `/etc/network/interfaces`
2. Checks that eno3 interface exists (Intel X520)
3. Generates new `/etc/network/interfaces` from template
4. Tests configuration with `ifreload -a -s` (dry run)
5. Applies configuration with `ifreload -a` if test passes
6. Verifies bridges are created

**Variables:**
- `storage_ip`: Host's storage VLAN IP (10.10.10.10 or .11)
- `management_ip`: Host's management IP (192.168.0.10 or .11)
- `gateway_ip`: Default gateway (192.168.0.1)

### Ansible Playbook: `configure-proxmox-networking.yml`

**Location:** `ansible/playbooks/configure-proxmox-networking.yml`

**What it does:**
1. Sets host-specific IPs based on inventory hostname
2. Displays configuration summary
3. Applies `proxmox_networking` role
4. Verifies bridges are configured
5. Shows next steps

### Terraform: `_proxmox-networking.tf`

**Location:** `terraform/_proxmox-networking.tf`

**What it does:**
1. Uses `null_resource` to trigger Ansible playbook
2. Waits for Proxmox hosts to be accessible
3. Runs Ansible playbook via `local-exec` provisioner
4. Shows configuration summary
5. Outputs bridge status

**Triggers:**
- `config_version`: Update to force re-run
- `vlans`: Changes to VLAN IDs in locals.tf

## Safety Features

### Automatic Backups

Every time the playbook runs, it backs up the current `/etc/network/interfaces`:
```bash
/etc/network/interfaces.backup.YYYYMMDD_HHMMSS
```

### Configuration Testing

Before applying changes, the playbook runs:
```bash
ifreload -a -s  # Simulates config without applying
```

If this fails, the playbook aborts and doesn't apply changes.

### SSH Connection Safety

**Risk:** If network configuration breaks, you lose SSH access.

**Mitigation:**
1. Always test with `--check` first
2. Use iDRAC for out-of-band access if needed:
   - grogu iDRAC: https://10.10.1.10
   - din iDRAC: https://10.10.1.11
3. Configuration is applied via `ifreload`, not `systemctl restart`, which is safer

### Rollback

If configuration breaks:

**Via SSH (if still accessible):**
```bash
# Restore backup
cp /etc/network/interfaces.backup.* /etc/network/interfaces
ifreload -a
```

**Via iDRAC (if SSH is broken):**
1. Open iDRAC console: https://10.10.1.10 or .11
2. Launch virtual console
3. Log in as root
4. Restore backup and reboot:
   ```bash
   cp /etc/network/interfaces.backup.* /etc/network/interfaces
   reboot
   ```

## Verification

After configuration:

**Check bridges:**
```bash
ssh root@192.168.0.10
ip addr show | grep vmbr
brctl show
```

**Expected output:**
```
vmbr10: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9000
    inet 10.10.10.10/24 ...
vmbr20: <BROADCAST,MULTICAST,UP,LOWER_UP>
    inet 192.168.0.10/24 ...
vmbr30: <BROADCAST,MULTICAST,UP,LOWER_UP>
vmbr31: <BROADCAST,MULTICAST,UP,LOWER_UP>
vmbr32: <BROADCAST,MULTICAST,UP,LOWER_UP>
```

**Test connectivity:**
```bash
# From laptop
ping 192.168.0.10    # Proxmox management
ping 10.10.10.10     # Storage interface (via router)

# From Proxmox host
ping 192.168.0.1     # Gateway
ping 10.10.10.1      # Storage gateway (router)
ping 192.168.0.53    # Pi-hole DNS
```

**Test VLAN routing:**
```bash
# From Proxmox host
ping 10.0.1.1        # K8s Shared gateway (should work after router config)
ping 10.0.2.1        # K8s Apps gateway
ping 10.0.3.1        # K8s Test gateway
```

## Next Steps

After configuring Proxmox networking:

1. **Configure router** - Add K8s VLANs 30-32 to CRS310-8G+2S+IN
   - See: `docs/network-architecture.md` (Router Configuration section)

2. **Deploy Kubernetes clusters:**
   ```bash
   cd terraform
   terraform apply  # Deploys VMs on vmbr30/vmbr31/vmbr32
   ```

3. **Verify K8s connectivity:**
   - Nodes should get IPs from VLAN 30-32 ranges
   - Nodes should reach gateway (10.0.X.1)
   - Nodes should reach TrueNAS storage (10.10.10.13)

## Troubleshooting

### Ansible playbook fails with "eno3 interface not found"

**Cause:** Intel X520 NIC not at eno3, or using different NIC.

**Fix:**
1. Check actual interface name:
   ```bash
   ssh root@192.168.0.10
   ip link show
   ```
2. Update `ansible/roles/proxmox_networking/defaults/main.yml`:
   ```yaml
   primary_interface: "ens4f0"  # or your actual interface
   ```

### Configuration applied but SSH connection lost

**Cause:** IP address or gateway misconfigured.

**Fix via iDRAC:**
1. Access iDRAC console: https://10.10.1.10
2. Launch virtual console
3. Log in as root
4. Check interfaces:
   ```bash
   ip addr show
   ip route show
   ```
5. Restore backup if needed:
   ```bash
   cp /etc/network/interfaces.backup.* /etc/network/interfaces
   reboot
   ```

### Bridges created but VMs can't get network

**Cause:** Router not configured with K8s VLANs yet, or VLAN trunk not working.

**Check router:**
1. Verify VLAN 30-32 exist on CRS310-8G+2S+IN
2. Verify SFP+ ports are trunking all VLANs
3. See: `docs/network-architecture.md` (Router Configuration)

**Check Proxmox:**
```bash
# Verify VLAN subinterfaces exist
ip link show eno3.30
ip link show eno3.31
ip link show eno3.32

# Should show "UP" and "PROMISC" (promiscuous mode)
```

### `ifreload -a` hangs or times out

**Cause:** Network loop, misconfigured bridge, or timing issue.

**Fix:**
1. Kill `ifreload` process (Ctrl+C)
2. Restore backup:
   ```bash
   cp /etc/network/interfaces.backup.* /etc/network/interfaces
   ```
3. Reboot:
   ```bash
   reboot
   ```

## Integration with Terraform Workflow

### Initial Setup (One-Time)

```bash
# 1. Configure Proxmox networking (creates bridges)
just proxmox-configure-networking-check  # Dry run
just proxmox-configure-networking        # Apply

# 2. Configure router (add K8s VLANs)
# See: docs/network-architecture.md (Router Configuration)

# 3. Deploy infrastructure
cd terraform
terraform init
terraform apply
```

### Ongoing Usage

After initial setup, Terraform will manage VMs/containers that **use** the bridges:

```hcl
# Kubernetes node uses vmbr31 (K8s Apps VLAN)
resource "proxmox_virtual_environment_vm" "k8s_worker" {
  name      = "talos-worker1"
  node_name = "grogu"

  network_device {
    bridge = "vmbr31"  # Bridge already exists from Ansible
    model  = "virtio"
  }
}
```

Terraform doesn't need to manage bridges anymore - Ansible configured them once, Terraform just uses them.

### Force Re-Configuration

If you need to update bridge configuration:

**Option 1: Via Ansible**
```bash
just proxmox-configure-networking
```

**Option 2: Via Terraform**
```bash
cd terraform

# Update trigger in _proxmox-networking.tf
# Change: config_version = "2024-02-02-k8s-vlans"
# To:     config_version = "2024-02-02-k8s-vlans-v2"

terraform apply -target=null_resource.proxmox_networking
```

## Why This Approach?

### Why not pure Terraform?

**Terraform Proxmox providers can't configure host networking.** They only manage:
- Virtual machines
- LXC containers
- Storage
- Firewall rules (VM-level)

They **cannot** configure:
- Network bridges
- VLAN interfaces
- Host IP addresses
- Host routing

### Why not pure Ansible?

**Ansible alone works fine!** But integrating with Terraform provides:
- **Single workflow:** `terraform apply` handles everything
- **Dependency management:** Bridges exist before VMs deploy
- **State tracking:** Terraform knows bridges were configured
- **Idempotency:** Won't reconfigure unless triggers change

### Why not configuration management (Puppet/Chef/Salt)?

**Overkill for static network configuration.** Network bridges are:
- Set once, rarely changed
- Simple configuration (5 bridges, fixed IPs)
- No need for continuous config management

Ansible playbook is:
- Simple (100 lines total)
- Fast (runs in 10 seconds)
- Easy to understand and modify

## Summary

**Short answer:** Proxmox networking **can't** be done in pure Terraform, but **can** be automated with Terraform + Ansible.

**Recommended approach:**
1. Run `just proxmox-configure-networking` once to set up bridges
2. Use Terraform to deploy VMs/containers that use those bridges
3. Re-run only if bridge configuration needs to change

**Files created:**
- `ansible/roles/proxmox_networking/` - Ansible role
- `ansible/playbooks/configure-proxmox-networking.yml` - Playbook
- `terraform/_proxmox-networking.tf` - Terraform integration
- Updated: `justfile` - Convenience commands
