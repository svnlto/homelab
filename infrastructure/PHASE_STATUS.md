# Terragrunt Migration - Phase Status

## Phase 1: Setup and Foundation ✅ COMPLETE

**Duration**: 2 hours
**Risk**: Low
**Date Completed**: 2026-02-03

### Completed Tasks

- ✅ Added Terragrunt to Nix flake.nix (v0.71.6)
- ✅ Created infrastructure/ directory structure (16 directories)
- ✅ Created globals.hcl (269 lines) - Single source of truth
- ✅ Created root.hcl with local state backend
- ✅ Updated .envrc with MikroTik and B2 credentials
- ✅ Updated .gitignore for Terragrunt artifacts
- ✅ Added 11 Terragrunt commands to justfile
- ✅ Validated Phase 1 setup

### Artifacts

- `infrastructure/globals.hcl` - Network config, VLANs, IPs, versions
- `infrastructure/root.hcl` - State management (local backend)
- `.terraform-state/` - Local state storage directory (gitignored)
- Updated environment files

---

## Phase 2: Proxmox State Migration ✅ COMPLETE (SIMPLIFIED)

**Duration**: 15 minutes
**Risk**: Low (no state migration needed)
**Status**: Complete
**Date Completed**: 2026-02-03

### Phase 1: Completed Tasks

- ✅ Created Proxmox provider.hcl
- ✅ Created TrueNAS Primary module (4 files: terragrunt.hcl, variables.tf, main.tf, outputs.tf)
- ✅ Created TrueNAS Backup module (4 files)
- ✅ Created Arr Stack LXC module (4 files)
- ✅ Created MIGRATION.md documentation
- ✅ VMs recreated from scratch (no state import needed)
- ✅ Archived old terraform/ directory → archive/terraform-legacy-20260203/
- ✅ Moved reusable modules to infrastructure/modules/

### Migration Approach

**Original Plan**: Import existing VMs from old Terraform state
**Actual**: VMs were recreated from scratch, eliminating need for state import/migration

This simplified approach:

- Eliminated risk of state corruption
- Faster than import process
- Clean slate for Terragrunt
- Old terraform configs archived for reference

### Phase 1: Artifacts

**Proxmox Modules**:

- `infrastructure/proxmox/provider.hcl`
- `infrastructure/proxmox/truenas-primary/` (6 files)
- `infrastructure/proxmox/truenas-backup/` (4 files)

**Archived**:

- `archive/terraform-legacy-20260203/` - Old terraform configs (reference only)

---

## Phase 3: MikroTik Integration ✅ SETUP COMPLETE

**Duration**: Estimated 5-7 hours
**Risk**: High (network reconfiguration)
**Status**: Module code complete, awaiting router setup and execution

### Phase 3: Completed Tasks

- ✅ Created MikroTik provider.hcl
- ✅ Created base networking module (bridge, VLANs, IPs, routing)
- ✅ Created DHCP modules for 4 VLANs (lan, k8s-shared, k8s-apps, k8s-test)
- ✅ Created firewall module (zone-based rules)
- ✅ Created DNS forwarding module (to Pi-hole)
- ✅ Created comprehensive SETUP.md documentation

### Pending Execution Steps

**Phase 0: Router Setup** (see infrastructure/mikrotik/SETUP.md):

1. Connect MikroTik CRS to network
2. Access via WebFig/Winbox
3. Create terraform user
4. Enable REST API with SSL certificate
5. Set static IP (192.168.0.2/24)
6. Test API access
7. Add credentials to .env

**Phase 3A: Base Networking** (⚠️ MAINTENANCE WINDOW):

```bash
cd infrastructure/mikrotik/base
terragrunt apply  # Creates VLANs, bridge, gateways
```

**Phase 3B: DHCP Servers**:

```bash
cd infrastructure/mikrotik/dhcp/vlan-20-lan && terragrunt apply
# Repeat for k8s VLANs
```

**Phase 3C: Firewall Rules** - Apply zone-based firewall:

```bash
cd infrastructure/mikrotik/firewall
terragrunt apply  # Zone-based firewall
```

**Phase 3D: DNS Forwarding** - Configure DNS forwarding to Pi-hole:

```bash
cd infrastructure/mikrotik/dns
terragrunt apply  # Forward to Pi-hole
```

### Artifacts Created

**MikroTik Modules**:

- `infrastructure/mikrotik/provider.hcl`
- `infrastructure/mikrotik/base/` (4 files: bridge, VLANs, IPs)
- `infrastructure/mikrotik/dhcp/vlan-20-lan/` (4 files)
- `infrastructure/mikrotik/dhcp/vlan-30-k8s-shared/` (4 files)
- `infrastructure/mikrotik/dhcp/vlan-31-k8s-apps/` (4 files)
- `infrastructure/mikrotik/dhcp/vlan-32-k8s-test/` (4 files)
- `infrastructure/mikrotik/firewall/` (4 files: zones, rules)
- `infrastructure/mikrotik/dns/` (4 files: Pi-hole forwarding)

**Documentation**:

- `infrastructure/mikrotik/SETUP.md` - Complete setup guide (350+ lines)

**Configuration**:

- 6 VLANs: management (1), storage (10), lan (20), k8s-shared (30), k8s-apps (31), k8s-test (32)
- 4 DHCP servers with IP pools
- Zone-based firewall (LAN → all, K8s → storage, K8s isolated)
- DNS forwarding to Pi-hole (192.168.0.53)

---

## Phase 4: B2 Remote State Migration 🔜 NOT STARTED

**Duration**: Estimated 1-2 hours
**Risk**: Medium
**Status**: Not started

### Prerequisites

- Backblaze B2 account (✅ created)
- B2 bucket: `homelab-terraform-state` (⏳ needs creation)
- B2 application key (⏳ needs creation)

### Phase 4: Planned Tasks

1. Create B2 bucket with versioning/lifecycle
2. Create restricted application key
3. Add B2 credentials to .env
4. Update root.hcl to use S3 backend
5. Migrate state: `terragrunt run-all init -migrate-state`
6. Verify remote state working

---

## Phase 5: Documentation and Cleanup 🔜 NOT STARTED

**Duration**: Estimated 1-2 hours
**Risk**: Low
**Status**: Not started

### Phase 5: Planned Tasks

1. Update CLAUDE.md with new structure
2. Create docs/terragrunt-migration.md summary
3. Create docs/mikrotik-management.md
4. Archive old terraform/ directory
5. Setup automated state backups (optional)
6. Final validation

---

## Overall Progress

| Phase | Status | Duration | Risk | Progress |
| ----- | ------ | -------- | ---- | -------- |
| 1. Setup | ✅ Complete | 2h | Low | 100% |
| 2. Proxmox Migration | ✅ Complete | 15m | Low | 100% |
| 3. MikroTik Integration | ⏳ Setup Complete | 5-7h | High | 75% |
| 4. B2 State Migration | 🔜 Not Started | 1-2h | Medium | 0% |
| 5. Documentation | 🔜 Not Started | 1-2h | Low | 0% |

**Total Estimated Time**: 2-3 weeks (part-time)
**Time Invested**: ~4.5 hours
**Completion**: ~60% (setup/code)

---

## Next Actions

### Immediate (Phase 3 Preparation)

**Option A: Deploy VMs with Terragrunt** (if VMs don't exist yet):

```bash
# Reload shell to get Terragrunt
exec $SHELL
cd ~/Projects/homelab

# Initialize and apply Proxmox modules
cd infrastructure/proxmox/truenas-primary && terragrunt init && terragrunt apply
cd ../truenas-backup && terragrunt init && terragrunt apply
cd ../arr-stack && terragrunt init && terragrunt apply
```

**Option B: Proceed to MikroTik Setup** (if VMs already deployed):

1. **MikroTik router physical setup** (see infrastructure/mikrotik/SETUP.md):
   - Connect CRS to network
   - Access via WebFig/Winbox
   - Create terraform user
   - Enable REST API with SSL
   - Configure static IP (192.168.0.2/24)
   - Add credentials to .env

2. **Schedule maintenance window** for Phase 3 (30-60 min network disruption)

3. **Execute Phase 3** during maintenance window (see infrastructure/mikrotik/SETUP.md)

---

## Rollback Capability

- ✅ Old terraform configs archived: `archive/terraform-legacy-20260203/`
- ✅ Git history: All changes committed
- ✅ Terragrunt local state: `.terraform-state/`
- ✅ State backup command available: `just tg-backup`

---

## Key Files

**Configuration**:

- `infrastructure/globals.hcl` - Single source of truth
- `infrastructure/root.hcl` - State management
- `infrastructure/proxmox/provider.hcl` - Proxmox provider
- `infrastructure/mikrotik/provider.hcl` - MikroTik provider

**Documentation**:

- `infrastructure/mikrotik/SETUP.md` - Phase 3 execution guide
- `infrastructure/PHASE_STATUS.md` - This file

**Backups**:

- `terraform/terraform.tfstate.backup.*` - State backups
- `.terraform-state/` - Terragrunt local state

**Justfile Commands**:

- `just tg-init`, `just tg-plan`, `just tg-apply`
- `just tg-apply-module MODULE`
- `just tg-backup`, `just tg-list`, `just tg-graph`
