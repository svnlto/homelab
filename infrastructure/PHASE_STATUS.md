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

## Phase 3: MikroTik Integration ✅ COMPLETE

**Duration**: ~8 hours
**Risk**: High (network reconfiguration)
**Status**: Complete — MikroTik is main gateway at 192.168.0.1
**Date Completed**: 2026-02-11

### Phase 3: Completed Tasks

- ✅ Created MikroTik provider.hcl
- ✅ Created base networking module (bridge, VLANs, IPs, routing)
- ✅ Created DHCP modules for 4 VLANs (lan, k8s-shared, k8s-apps, k8s-test)
- ✅ Created firewall module (zone-based rules with `routeros_move_items`)
- ✅ Created DNS forwarding module (to Pi-hole)
- ✅ Created comprehensive SETUP.md documentation
- ✅ **Router Setup** — CRS310-8G+2S+IN, terraform user, HTTPS API with SSL
- ✅ **Base Networking** — VLAN-aware bridge, 6 VLANs, access/trunk ports
- ✅ **DNS Forwarding** — Router DNS set to Pi-hole (192.168.0.53)
- ✅ **K8s DHCP** — DHCP servers for VLANs 30, 31, 32
- ✅ **Gateway Migration** — MikroTik at 192.168.0.1, WAN on ether1,
  NAT/masquerade, input chain firewall, Beryl AX switched to AP mode
- ✅ **LAN DHCP** — DHCP server for VLAN 20 (192.168.0.100-149)
- ✅ **Firewall** — Input chain (8 rules) + forward chain (9 rules)
- ✅ **Terragrunt state aligned** — All resources imported and applied

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

## Phase 4: B2 Remote State Migration ✅ COMPLETE

**Duration**: 30 minutes
**Risk**: Medium
**Status**: Complete
**Date Completed**: 2026-02-03

### Prerequisites

- Backblaze B2 account (✅ created)
- B2 bucket: `svnlto-homelab-terraform-state` (✅ created in EU Central/Amsterdam)
- B2 application key (✅ stored in 1Password)

### Phase 4: Completed Tasks

1. ✅ Created B2 bucket in Amsterdam datacenter (eu-central-003)
   - Bucket: `svnlto-homelab-terraform-state`
   - Type: Private
   - Lifecycle: Keep all versions
   - Endpoint: `s3.eu-central-003.backblazeb2.com`

2. ✅ Added B2 credentials to 1Password
   - Stored in "Backblaze B2" item
   - Auto-loaded via .envrc

3. ✅ Updated root.hcl to use S3-compatible backend
   - Configured B2 endpoint with S3 compatibility flags
   - Added encryption at rest

4. ✅ Migrated state for all modules:
   - prod/resource-pools
   - prod/iso-images
   - prod/storage/truenas-primary
   - prod/storage/truenas-backup

5. ✅ Verified remote state working (terragrunt plan successful)

6. ✅ Archived and removed local state
   - Backup: `archive/terraform-state-local-backup-20260203.tar.gz`
   - Deleted: `infrastructure/.terraform-state/`

### Benefits Achieved

- **Disaster Recovery**: State stored in geo-redundant B2 bucket (Amsterdam)
- **Team Collaboration**: Remote state enables multi-user workflows
- **Version History**: B2 keeps all state versions for rollback
- **Security**: Encrypted state with 1Password credential management
- **Cost Efficient**: B2 pricing cheaper than AWS S3 for storage

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
| 3. MikroTik Integration | ✅ Complete | ~8h | High | 100% |
| 4. B2 State Migration | ✅ Complete | 30m | Medium | 100% |
| 5. Documentation | 🔜 Not Started | 1-2h | Low | 0% |

**Total Estimated Time**: 2-3 weeks (part-time)
**Time Invested**: ~7 hours
**Completion**: ~95%

---

## Next Actions

1. **Phase 5: Documentation cleanup**
2. Deploy Kubernetes clusters on K8s VLANs (30-32)
3. Add MikroTik to observability stack

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
