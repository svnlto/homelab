default:
    @just --list

# =============================================================================
# Pi-hole (Raspberry Pi - NixOS declarative approach)
# =============================================================================
# NOTE: Replaced Packer + Ansible + Docker approach (removed Jan 2026)
# Old approach: 30-60 min builds, 15+ chroot workarounds, manual SD reflash for rollback
# NixOS approach: 2-5 min incremental builds, zero workarounds, 30-sec atomic rollback
# Configuration: nix/rpi-pihole/
# =============================================================================

# Start NixOS build VM (one-time or after destroying)
nixos-vm-up:
    cd nix && vagrant up

# Stop NixOS build VM
nixos-vm-down:
    cd nix && vagrant halt

# Destroy NixOS build VM
nixos-vm-destroy:
    cd nix && vagrant destroy -f

# SSH into NixOS build VM
nixos-vm-ssh:
    cd nix && vagrant ssh

# Build NixOS SD image for Pi-hole inside Linux VM (15-20 min first build, 2-5 min incremental)
nixos-build-pihole:
    @echo "Building NixOS SD image for Pi-hole in Linux VM..."
    cd nix && vagrant ssh -c "cd /vagrant && nix build .#nixosConfigurations.rpi-pihole.config.system.build.sdImage"
    @echo ""
    @echo "✓ Image built successfully!"
    @ls -lh nix/result/sd-image/*.img 2>/dev/null || echo "Image will be in nix/result/sd-image/"

# Flash NixOS image to SD card
nixos-flash-pihole disk:
    #!/usr/bin/env bash
    set -euo pipefail
    IMAGE=$$(ls nix/result/sd-image/*.img 2>/dev/null | head -n1)
    if [ -z "$$IMAGE" ]; then
      echo "Error: No NixOS image found. Run 'just nixos-build-pihole' first."
      exit 1
    fi
    echo "Flashing $$IMAGE to {{disk}}"
    echo "⚠️  This will DESTROY all data on {{disk}}!"
    read -p "Continue? (y/N) " -n 1 -r
    echo
    if [[ $$REPLY =~ ^[Yy]$$ ]]; then
      sudo dd if="$$IMAGE" of={{disk}} bs=4M status=progress conv=fsync
      diskutil eject {{disk}}
      echo "✓ Done! SD card ejected."
    else
      echo "Aborted."
    fi

# Update NixOS flake lock (get latest packages) - runs in VM
nixos-update-pihole:
    @echo "Updating NixOS flake lock in VM..."
    cd nix && vagrant ssh -c "cd /vagrant && nix flake update"
    @echo "✓ Flake updated. Run 'just nixos-build-pihole' to rebuild."

# Check NixOS configuration (syntax validation) - runs in VM
nixos-check-pihole:
    @echo "Checking NixOS configuration in VM..."
    cd nix && vagrant ssh -c "cd /vagrant && nix flake check"

# =============================================================================
# Proxmox VM Template (builds templates inside Proxmox for Terraform cloning)
# =============================================================================

packer-init-vm-template:
    cd packer/proxmox-templates && packer init ubuntu-24.04-template.pkr.hcl

packer-validate-vm-template:
    cd packer/proxmox-templates && packer validate ubuntu-24.04-template.pkr.hcl

packer-build-vm-template:
    @echo "Building Ubuntu VM template inside Proxmox (15-30 min)..."
    cd packer/proxmox-templates && packer init ubuntu-24.04-template.pkr.hcl && packer build ubuntu-24.04-template.pkr.hcl

# =============================================================================
# Ansible
# =============================================================================

ansible-lint:
    ANSIBLE_CONFIG=ansible/ansible.cfg ansible-lint -c .ansible-lint.yaml ansible/

ansible-playbook PLAYBOOK:
    cd ansible && ansible-playbook playbooks/{{PLAYBOOK}}

# Configure all existing Proxmox nodes (grogu + din)
ansible-configure-all:
    cd ansible && ansible-playbook -i inventory.ini playbooks/configure-existing-proxmox.yml

# Configure specific Proxmox node
ansible-configure HOST:
    cd ansible && ansible-playbook -i inventory.ini playbooks/configure-existing-proxmox.yml -l {{HOST}}

# Test connectivity to Proxmox nodes
ansible-ping:
    cd ansible && ansible -i inventory.ini proxmox -m ping

# =============================================================================
# TrueNAS (Storage)
# =============================================================================

# Test connectivity to TrueNAS hosts
truenas-ping:
    cd ansible && ansible -i inventory.ini truenas -m ping

# Test connectivity to primary TrueNAS only
truenas-ping-primary:
    cd ansible && ansible -i inventory.ini truenas_primary -m ping

# Test connectivity to backup TrueNAS only
truenas-ping-backup:
    cd ansible && ansible -i inventory.ini truenas_backup -m ping

# Setup TrueNAS primary (din) - datasets, shares, snapshots
truenas-setup:
    @echo "Configuring TrueNAS SCALE on din (192.168.0.13)..."
    cd ansible && ansible-playbook -i inventory.ini playbooks/truenas-setup.yml

# Setup TrueNAS with check mode (dry run)
truenas-setup-check:
    @echo "Dry run: Configuring TrueNAS SCALE on din..."
    cd ansible && ansible-playbook -i inventory.ini playbooks/truenas-setup.yml --check

# Setup TrueNAS backup (grogu) - replication target datasets
truenas-backup-setup:
    @echo "Configuring TrueNAS SCALE backup on grogu (192.168.0.14)..."
    cd ansible && ansible-playbook -i inventory.ini playbooks/truenas-backup-setup.yml

# Setup TrueNAS backup with check mode (dry run)
truenas-backup-setup-check:
    @echo "Dry run: Configuring TrueNAS SCALE backup on grogu..."
    cd ansible && ansible-playbook -i inventory.ini playbooks/truenas-backup-setup.yml --check

# Setup TrueNAS replication (din → grogu)
truenas-replication:
    @echo "Setting up ZFS replication from din to grogu..."
    cd ansible && ansible-playbook -i inventory.ini playbooks/truenas-replication.yml

# Run specific TrueNAS tags
truenas-setup-tags TAGS:
    cd ansible && ansible-playbook -i inventory.ini playbooks/truenas-setup.yml --tags {{TAGS}}

# Query TrueNAS pool status
truenas-pools:
    @echo "=== TrueNAS Pools on din ==="
    ssh root@192.168.0.13 "midclt call pool.query | jq '.[] | {name, status, topology}'"

# Query TrueNAS datasets
truenas-datasets:
    @echo "=== TrueNAS Datasets on din ==="
    ssh root@192.168.0.13 "midclt call pool.dataset.query | jq '.[] | {name, used, available}'"

# Query TrueNAS NFS shares
truenas-shares:
    @echo "=== TrueNAS NFS Shares on din ==="
    ssh root@192.168.0.13 "midclt call sharing.nfs.query | jq '.[] | {path, comment, networks}'"

# Query TrueNAS replication tasks
truenas-replication-status:
    @echo "=== TrueNAS Replication Tasks on din ==="
    ssh root@192.168.0.13 "midclt call replication.query | jq '.[] | {name, state, source_datasets, target_dataset}'"

# Query TrueNAS snapshot tasks
truenas-snapshots:
    @echo "=== TrueNAS Snapshot Tasks on din ==="
    ssh root@192.168.0.13 "midclt call pool.snapshottask.query | jq '.[] | {dataset, naming_schema, lifetime_value, lifetime_unit}'"

# Query backup TrueNAS pool status
truenas-backup-pools:
    @echo "=== TrueNAS Backup Pool on grogu ==="
    ssh root@192.168.0.14 "midclt call pool.query | jq '.[] | {name, status, topology}'"

# Query backup TrueNAS datasets
truenas-backup-datasets:
    @echo "=== TrueNAS Backup Datasets on grogu ==="
    ssh root@192.168.0.14 "midclt call pool.dataset.query | jq '.[] | {name, used, available}'"

# Query backup TrueNAS snapshot tasks
truenas-backup-snapshots:
    @echo "=== TrueNAS Backup Snapshot Tasks on grogu ==="
    ssh root@192.168.0.14 "midclt call pool.snapshottask.query | jq '.[] | {dataset, naming_schema, lifetime_value, lifetime_unit}'"

# Full TrueNAS status check (both primary and backup)
truenas-status-all:
    @echo "=== PRIMARY TRUENAS (din) ==="
    @just truenas-pools
    @echo ""
    @echo "=== BACKUP TRUENAS (grogu) ==="
    @just truenas-backup-pools
    @echo ""
    @echo "=== REPLICATION STATUS ==="
    @just truenas-replication-status

# =============================================================================
# Restic Cloud Backup (B2)
# =============================================================================

# Setup Restic backup to Backblaze B2
restic-setup:
    @echo "Setting up Restic backup to Backblaze B2..."
    cd ansible && ansible-playbook -i inventory.ini playbooks/truenas-restic-backup.yml --ask-vault-pass

# Check Restic backup status
restic-status:
    @echo "Checking Restic backup status..."
    ssh root@192.168.0.13 "/root/scripts/restic-status.sh"

# List Restic snapshots
restic-snapshots:
    @echo "=== Restic Snapshots ==="
    ssh root@192.168.0.13 "source /root/.restic-env && restic snapshots"

# List snapshots by tag
restic-snapshots-tag TAG:
    @echo "=== Restic Snapshots: {{TAG}} ==="
    ssh root@192.168.0.13 "source /root/.restic-env && restic snapshots --tag {{TAG}}"

# Manually trigger backup (all jobs)
restic-backup-now:
    @echo "Running all Restic backups manually..."
    ssh root@192.168.0.13 "systemctl start restic-backup-critical.service restic-backup-photos.service restic-backup-bulk.service"

# Manually trigger critical backup
restic-backup-critical:
    @echo "Running critical data backup..."
    ssh root@192.168.0.13 "systemctl start restic-backup-critical.service"

# Manually trigger photos backup
restic-backup-photos:
    @echo "Running photos backup..."
    ssh root@192.168.0.13 "systemctl start restic-backup-photos.service"

# Check Restic timers
restic-timers:
    @echo "=== Restic Backup Timers ==="
    ssh root@192.168.0.13 "systemctl list-timers restic-backup-* --no-pager"

# View Restic backup logs
restic-logs:
    @echo "=== Recent Restic Backup Logs ==="
    ssh root@192.168.0.13 "journalctl -u 'restic-backup-*' -n 50 --no-pager"

# Follow Restic backup logs (live)
restic-logs-follow:
    ssh root@192.168.0.13 "journalctl -u 'restic-backup-*' -f"

# Check Restic repository stats
restic-stats:
    @echo "=== Restic Repository Statistics ==="
    ssh root@192.168.0.13 "source /root/.restic-env && restic stats --mode raw-data"

# Restore files from Restic (interactive)
restic-restore:
    @echo "=== Restic Restore (Interactive) ==="
    @echo "This will open an SSH session. Run:"
    @echo "  source /root/.restic-env"
    @echo "  restic snapshots  # Find snapshot ID"
    @echo "  restic restore <snapshot-id> --target /tmp/restore"
    ssh root@192.168.0.13

# Verify Restic repository integrity
restic-check:
    @echo "Running Restic repository integrity check (may take hours)..."
    ssh root@192.168.0.13 "source /root/.restic-env && restic check --read-data"

# =============================================================================
# Terraform
# =============================================================================

# Terraform init
tf-init:
    cd terraform && terraform init

# Terraform plan
tf-plan:
    cd terraform && terraform plan

# Terraform apply
tf-apply:
    cd terraform && terraform apply

# Terraform destroy
tf-destroy:
    cd terraform && terraform destroy

# Terraform validate
tf-validate:
    cd terraform && terraform validate

# Terraform fmt
tf-fmt:
    cd terraform && terraform fmt -recursive

# =============================================================================
# Utilities
# =============================================================================

# Clean build artifacts
clean:
    rm -rf packer/*/output/
    rm -rf packer/*/.packer_cache/
    rm -rf nix/result nix/result-*

# Run pre-commit hooks
lint:
    pre-commit run --all-files
