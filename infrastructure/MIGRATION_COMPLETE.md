# Terraform to Terragrunt Migration - Complete

**Migration Date**: 2026-02-03
**Status**: ✅ Complete

## Migration Summary

All Terraform code has been successfully migrated to Terragrunt with improved DRY configuration and environment separation.

### What Was Migrated

| Old Location | New Location | Status |
| ------------ | ------------ | ------ |
| `terraform/_truenas.tf` | `infrastructure/prod/storage/truenas-primary/` | ✅ Migrated + HBA passthrough restored |
| `terraform/_truenas-backup.tf` | `infrastructure/prod/storage/truenas-backup/` | ✅ Migrated (awaiting grogu node) |
| `terraform/modules/talos-cluster/` | `infrastructure/modules/talos-cluster/` | ✅ Migrated |

### What Was Removed

| Old File | Reason | Alternative |
| -------- | ------ | ----------- |
| `terraform/_arrstack.tf` | VMs recreated from scratch | Can be recreated via new modules |
| `terraform/_proxmox-networking.tf` | Null resource trigger | Ansible handles directly |
| `terraform/modules/ubuntu-vm/` | Not needed | VMs recreated without template |

### Infrastructure Improvements

**Before (Terraform)**:

- Monolithic configuration in single directory
- Duplicated code for TrueNAS Primary and Backup
- No environment separation
- Local state only

**After (Terragrunt)**:

- Environment-based structure (prod/, dev/)
- DRY configuration with centralized globals.hcl
- Reusable modules (truenas-vm, talos-cluster)
- Resource pool management
- Centralized ISO management
- Remote state ready (B2 backend prepared)

### File Structure

```text
infrastructure/
├── globals.hcl                    # Single source of truth
├── root.hcl                       # Backend + provider config
├── modules/                       # Reusable modules
│   ├── truenas-vm/               # NEW: DRY TrueNAS module
│   └── talos-cluster/            # Migrated from old modules/
├── prod/                          # Production environment
│   ├── provider.hcl
│   ├── resource-pools/           # NEW: Proxmox pool management
│   ├── iso-images/               # NEW: Centralized ISO downloads
│   ├── storage/
│   │   ├── truenas-primary/      # Migrated from _truenas.tf
│   │   └── truenas-backup/       # Migrated from _truenas-backup.tf
│   └── mikrotik/                 # NEW: Router configuration
└── dev/                           # Development environment
    ├── provider.hcl
    └── resource-pools/
```

### Deployment Status

✅ **ISO Images** - TrueNAS ISO adopted into state
✅ **Resource Pools** - prod-storage, prod-compute created
✅ **TrueNAS Primary (VMID 300)** - Deployed on din with H330 HBA passthrough
⏸️ **TrueNAS Backup (VMID 301)** - Ready to deploy when grogu comes online

### Pre-commit Hooks

**Cleaned up**:

- ❌ Removed legacy terraform hooks (terraform/ directory gone)
- ❌ Disabled terragrunt_fmt/validate (requires direnv)
- ✅ Kept terraform_fmt for infrastructure/*.tf files
- ✅ All other hooks (yamlfmt, markdownlint, ansible-lint) passing

### Next Steps

1. **Switch Installation** - Install MikroTik CRS switch to bring grogu online
2. **TrueNAS Backup** - Deploy VMID 301 once grogu is available
3. **MikroTik Configuration** - Apply router config (VLANs, firewall, DHCP)
4. **B2 Remote State** - Migrate to BackBlaze B2 backend
5. **Talos Clusters** - Deploy Kubernetes clusters using talos-cluster module

## Verification

### Check Migration

```bash
# Verify old directory is gone
ls terraform/  # Should not exist

# Verify archive exists
ls archive/terraform-legacy-20260203/

# Verify new structure
ls infrastructure/prod/storage/
ls infrastructure/modules/

# Check resource pool assignment
cd infrastructure/prod/storage/truenas-primary
terragrunt state show 'module.truenas_primary.proxmox_virtual_environment_vm.truenas'
```

### Run Pre-commit

```bash
pre-commit run --all-files
```

All checks should pass.

## Rollback (If Needed)

If you need to reference old configurations:

```bash
# Old configs are archived for reference
cd archive/terraform-legacy-20260203/

# Files are read-only, do not modify
```

## Documentation Updates

- ✅ `.pre-commit-config.yaml` - Removed legacy hooks
- ✅ `infrastructure/globals.hcl` - Added resource mappings for HBA passthrough
- ✅ All markdown files pass markdownlint
- ⏳ `CLAUDE.md` - Needs update with new Terragrunt workflow (Phase 5)
