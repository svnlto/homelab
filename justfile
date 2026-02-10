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
    cd nix && vagrant ssh -c 'cd /tmp && rm -rf nix-build && mkdir nix-build && cd nix-build && rsync -a --exclude=".vagrant" --exclude="result*" --exclude="*.img" --exclude="*.qcow2" --exclude="*.vma.zst" /vagrant/ . && nix build .#nixosConfigurations.rpi-pihole.config.system.build.sdImage && cp -L result/sd-image/*.img /vagrant/pihole-nixos.img'
    @echo ""
    @echo "✓ Image built successfully!"
    @ls -lh nix/pihole-nixos.img

# Flash NixOS image to SD card
nixos-flash-pihole disk:
    #!/usr/bin/env bash
    set -euo pipefail
    IMAGE="nix/pihole-nixos.img"
    if [ ! -f "$IMAGE" ]; then
      echo "Error: No NixOS image found. Run 'just nixos-build-pihole' first."
      exit 1
    fi
    echo "Flashing $IMAGE to {{disk}}"
    echo "⚠️  This will DESTROY all data on {{disk}}!"
    read -p "Continue? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      echo "Unmounting {{disk}}..."
      diskutil unmountDisk {{disk}}
      echo "Flashing image (this will take ~5 minutes)..."
      sudo dd if="$IMAGE" of={{disk}} bs=1048576
      diskutil eject {{disk}}
      echo "✓ Done! SD card ejected."
    else
      echo "Aborted."
    fi

# Update NixOS flake lock (get latest packages) - runs in VM
nixos-flake-update-pihole:
    @echo "Updating NixOS flake lock in VM..."
    cd nix && vagrant ssh -c "cd /vagrant && nix flake update"
    @echo "✓ Flake updated. Run 'just nixos-build-pihole' to rebuild."

# Check NixOS configuration (syntax validation) - runs in VM
nixos-check-pihole:
    @echo "Checking NixOS configuration in VM..."
    cd nix && vagrant ssh -c "cd /vagrant && nix flake check"

# Clean up NixOS build artifacts in VM (frees space)
nixos-clean:
    @echo "Cleaning up NixOS build artifacts in VM..."
    cd nix && vagrant ssh -c "sudo rm -rf /tmp/nix-* /tmp/nixos-build /tmp/tmp.* && nix-collect-garbage -d && df -h /"
    @echo "✓ Cleanup complete"

# =============================================================================
# Arr Stack (Proxmox VM - NixOS declarative approach)
# =============================================================================
# Install NixOS on the arr-stack VM using nixos-anywhere.
# Builds on the target VM (native x86_64), no local image building needed.
# Prerequisites: VM 200 running NixOS live ISO, root SSH access to it.
# Configuration: nix/arr-stack/
# =============================================================================

# Install NixOS on arr-stack VM via nixos-anywhere (pass the live ISO's IP)
nixos-install-arr-stack ip:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Installing NixOS arr-stack to VM at {{ip}}..."
    echo "This will partition the disk, install NixOS, and reboot."
    cd nix && nix --extra-experimental-features "nix-command flakes" run github:nix-community/nixos-anywhere -- \
      --flake .#arr-stack \
      --build-on-remote \
      root@{{ip}}
    echo "NixOS installed! VM will reboot to 192.168.0.50"
    echo "SSH: ssh svenlito@192.168.0.50"

# Deploy Pi-hole NixOS configuration via SSH (rebuilds on the Pi)
nixos-deploy-pihole:
    @echo "Syncing NixOS config to rpi-pihole..."
    rsync -a --exclude='.vagrant' --exclude='result*' --exclude='*.img' --exclude='*.qcow2' nix/ svenlito@192.168.0.53:/tmp/nix-config/
    @echo "Rebuilding NixOS on rpi-pihole..."
    ssh svenlito@192.168.0.53 "sudo nixos-rebuild switch --flake /tmp/nix-config#rpi-pihole"

# Update arr-stack NixOS configuration (after initial install)
nixos-update-arr-stack:
    @echo "Syncing NixOS config to arr-stack..."
    rsync -a --exclude='.vagrant' --exclude='result*' --exclude='*.img' --exclude='*.qcow2' nix/ svenlito@192.168.0.50:/tmp/nix-config/
    @echo "Rebuilding NixOS on arr-stack..."
    ssh svenlito@192.168.0.50 "sudo nixos-rebuild switch --flake /tmp/nix-config#arr-stack"

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

# Configure Proxmox network bridges (VLAN 10, 20, 30-32 for K8s)
proxmox-configure-networking:
    cd ansible && ansible-playbook -i inventory.ini playbooks/configure-proxmox-networking.yml

# Configure Proxmox networking on specific host only
proxmox-configure-networking-host HOST:
    cd ansible && ansible-playbook -i inventory.ini playbooks/configure-proxmox-networking.yml --limit {{HOST}}

# Test Proxmox network configuration (dry-run)
proxmox-configure-networking-check:
    cd ansible && ansible-playbook -i inventory.ini playbooks/configure-proxmox-networking.yml --check

# Create Terraform API tokens on all Proxmox nodes
proxmox-create-api-tokens:
    @echo "Creating Terraform API tokens on all Proxmox nodes..."
    cd ansible && ansible-playbook -i inventory.ini playbooks/configure-existing-proxmox.yml --tags api-tokens

# Rotate Terraform API tokens on all Proxmox nodes
proxmox-rotate-api-tokens:
    @echo "Rotating Terraform API tokens on all Proxmox nodes..."
    cd ansible && ansible-playbook -i inventory.ini playbooks/configure-existing-proxmox.yml --tags api-tokens -e rotate_tokens=true

# View stored API tokens (from 1Password)
proxmox-view-tokens:
    @echo "=== Proxmox API Tokens ==="
    @op read "op://Personal/Proxmox API Token/token_id" 2>/dev/null && op read "op://Personal/Proxmox API Token/token_secret" 2>/dev/null || echo "Failed to read tokens from 1Password"

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
# Terraform (Legacy - will be deprecated after Terragrunt migration)
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
# Terragrunt (New Infrastructure Management)
# =============================================================================

# Initialize all Terragrunt modules
tg-init:
    cd infrastructure && terragrunt run-all init

# Plan all Terragrunt modules
tg-plan:
    cd infrastructure && terragrunt run-all plan

# Apply all Terragrunt modules
tg-apply:
    cd infrastructure && terragrunt run-all apply

# Destroy all Terragrunt modules
tg-destroy:
    cd infrastructure && terragrunt run-all destroy

# Validate all Terragrunt configurations
tg-validate:
    cd infrastructure && terragrunt run-all validate

# Format all Terragrunt/Terraform files
tg-fmt:
    cd infrastructure && terragrunt run-all fmt

# Apply a specific module (e.g., just tg-apply-module proxmox/truenas-primary)
tg-apply-module MODULE:
    cd infrastructure/{{MODULE}} && terragrunt apply

# Plan a specific module
tg-plan-module MODULE:
    cd infrastructure/{{MODULE}} && terragrunt plan

# Destroy a specific module
tg-destroy-module MODULE:
    cd infrastructure/{{MODULE}} && terragrunt destroy

# Show Terragrunt module dependencies
tg-graph:
    cd infrastructure && terragrunt graph-dependencies

# Backup Terragrunt state files
tg-backup:
    #!/usr/bin/env bash
    set -euo pipefail
    BACKUP_DIR="infrastructure/.backups/$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    if [ -d ".terraform-state" ]; then
      cp -r .terraform-state "$BACKUP_DIR/"
      echo "✓ State backed up to $BACKUP_DIR"
    else
      echo "No state directory found (.terraform-state/)"
    fi

# List all Terragrunt modules
tg-list:
    @echo "=== Terragrunt Modules ==="
    @find infrastructure -name "terragrunt.hcl" -not -path "*/.terragrunt-cache/*" | sed 's|infrastructure/||g' | sed 's|/terragrunt.hcl||g' | sort

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
