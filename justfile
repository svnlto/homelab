default:
    @just --list

# --- NixOS Pi-hole (Raspberry Pi) ---

# Start build VM (one-time)
nixos-vm-up:
    cd nix && vagrant up

# Stop build VM
nixos-vm-down:
    cd nix && vagrant halt

# Destroy build VM
nixos-vm-destroy:
    cd nix && vagrant destroy -f

# SSH into build VM
nixos-vm-ssh:
    cd nix && vagrant ssh

# Build SD image in VM (15-20 min first, 2-5 min incremental)
nixos-build-pihole:
    @echo "Building NixOS SD image for Pi-hole in Linux VM..."
    cd nix && vagrant ssh -c 'cd /tmp && rm -rf nix-build && mkdir nix-build && cd nix-build && rsync -a --exclude=".vagrant" --exclude="result*" --exclude="*.img" --exclude="*.qcow2" --exclude="*.vma.zst" /vagrant/ . && nix build .#nixosConfigurations.rpi-pihole.config.system.build.sdImage && cp -L result/sd-image/*.img /vagrant/pihole-nixos.img'
    @ls -lh nix/pihole-nixos.img

# Flash SD image to disk
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
      diskutil unmountDisk {{disk}}
      sudo dd if="$IMAGE" of={{disk}} bs=1048576
      diskutil eject {{disk}}
      echo "✓ Done!"
    else
      echo "Aborted."
    fi

# Deploy Pi-hole config via SSH
nixos-deploy-pihole:
    @echo "Syncing NixOS config to rpi-pihole..."
    rsync -a --exclude='.vagrant' --exclude='result*' --exclude='*.img' --exclude='*.qcow2' nix/ svenlito@192.168.0.53:/tmp/nix-config/
    @echo "Rebuilding NixOS on rpi-pihole..."
    ssh svenlito@192.168.0.53 "sudo nixos-rebuild switch --flake /tmp/nix-config#rpi-pihole"

# Update flake lock in VM
nixos-flake-update-pihole:
    cd nix && vagrant ssh -c "cd /vagrant && nix flake update"

# Validate NixOS config in VM
nixos-check-pihole:
    cd nix && vagrant ssh -c "cd /vagrant && nix flake check"

# Free disk space in VM
nixos-clean:
    cd nix && vagrant ssh -c "sudo rm -rf /tmp/nix-* /tmp/nixos-build /tmp/tmp.* && nix-collect-garbage -d && df -h /"

# --- NixOS QDevice (Raspberry Pi) ---

# Build SD image for QDevice in VM
nixos-build-qdevice:
    @echo "Building NixOS SD image for QDevice in Linux VM..."
    cd nix && vagrant ssh -c 'cd /tmp && rm -rf nix-build && mkdir nix-build && cd nix-build && rsync -a --exclude=".vagrant" --exclude="result*" --exclude="*.img" --exclude="*.qcow2" --exclude="*.vma.zst" /vagrant/ . && nix build .#nixosConfigurations.rpi-qdevice.config.system.build.sdImage && cp -L result/sd-image/*.img /vagrant/qdevice-nixos.img'
    @ls -lh nix/qdevice-nixos.img

# Flash QDevice SD image to disk
nixos-flash-qdevice disk:
    #!/usr/bin/env bash
    set -euo pipefail
    IMAGE="nix/qdevice-nixos.img"
    if [ ! -f "$IMAGE" ]; then
      echo "Error: No NixOS image found. Run 'just nixos-build-qdevice' first."
      exit 1
    fi
    echo "Flashing $IMAGE to {{disk}}"
    echo "WARNING: This will DESTROY all data on {{disk}}!"
    read -p "Continue? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      diskutil unmountDisk {{disk}}
      sudo dd if="$IMAGE" of={{disk}} bs=1048576
      diskutil eject {{disk}}
      echo "Done!"
    else
      echo "Aborted."
    fi

# Deploy QDevice config via SSH
nixos-deploy-qdevice:
    @echo "Syncing NixOS config to rpi-qdevice..."
    rsync -a --exclude='.vagrant' --exclude='result*' --exclude='*.img' --exclude='*.qcow2' nix/ svenlito@192.168.0.54:/tmp/nix-config/
    @echo "Rebuilding NixOS on rpi-qdevice..."
    ssh svenlito@192.168.0.54 "sudo nixos-rebuild switch --flake /tmp/nix-config#rpi-qdevice"

# --- NixOS Arr Stack (Proxmox VM) ---

# Install NixOS on arr-stack VM via nixos-anywhere
nixos-install-arr-stack ip:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Installing NixOS arr-stack to VM at {{ip}}..."
    cd nix && nix --extra-experimental-features "nix-command flakes" run github:nix-community/nixos-anywhere -- \
      --flake .#arr-stack \
      --build-on-remote \
      root@{{ip}}
    echo "Done! SSH: ssh svenlito@192.168.0.50"

# Deploy arr-stack config via SSH
nixos-update-arr-stack:
    @echo "Syncing NixOS config to arr-stack..."
    rsync -a --exclude='.vagrant' --exclude='result*' --exclude='*.img' --exclude='*.qcow2' nix/ svenlito@192.168.0.50:/tmp/nix-config/
    @echo "Rebuilding NixOS on arr-stack..."
    ssh svenlito@192.168.0.50 "sudo nixos-rebuild switch --flake /tmp/nix-config#arr-stack"

# --- NixOS Jellyfin (Proxmox VM) ---

# Install NixOS on jellyfin VM via nixos-anywhere
nixos-install-jellyfin ip:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Installing NixOS jellyfin to VM at {{ip}}..."
    cd nix && nix --extra-experimental-features "nix-command flakes" run github:nix-community/nixos-anywhere -- \
      --flake .#jellyfin \
      --build-on-remote \
      root@{{ip}}
    echo "Done! SSH: ssh svenlito@192.168.0.51"

# Deploy jellyfin config via SSH
nixos-update-jellyfin:
    @echo "Syncing NixOS config to jellyfin..."
    rsync -a --exclude='.vagrant' --exclude='result*' --exclude='*.img' --exclude='*.qcow2' nix/ svenlito@192.168.0.51:/tmp/nix-config/
    @echo "Rebuilding NixOS on jellyfin..."
    ssh svenlito@192.168.0.51 "sudo nixos-rebuild switch --flake /tmp/nix-config#jellyfin"

# --- Ansible ---

ansible-lint:
    ANSIBLE_CONFIG=ansible/ansible.cfg ansible-lint -c .ansible-lint.yaml ansible/

ansible-playbook PLAYBOOK:
    cd ansible && ansible-playbook playbooks/{{PLAYBOOK}}

# Configure all Proxmox nodes
ansible-configure-all:
    cd ansible && ansible-playbook -i inventory.ini playbooks/configure-existing-proxmox.yml

# Configure specific Proxmox node
ansible-configure HOST:
    cd ansible && ansible-playbook -i inventory.ini playbooks/configure-existing-proxmox.yml -l {{HOST}}

# Test Proxmox connectivity
ansible-ping:
    cd ansible && ansible -i inventory.ini proxmox -m ping

# Configure Proxmox VLAN bridges
proxmox-configure-networking:
    cd ansible && ansible-playbook -i inventory.ini playbooks/configure-proxmox-networking.yml

proxmox-configure-networking-host HOST:
    cd ansible && ansible-playbook -i inventory.ini playbooks/configure-proxmox-networking.yml --limit {{HOST}}

proxmox-configure-networking-check:
    cd ansible && ansible-playbook -i inventory.ini playbooks/configure-proxmox-networking.yml --check

# Create API tokens on all nodes
proxmox-create-api-tokens:
    cd ansible && ansible-playbook -i inventory.ini playbooks/configure-existing-proxmox.yml --tags api-tokens

# Rotate API tokens
proxmox-rotate-api-tokens:
    cd ansible && ansible-playbook -i inventory.ini playbooks/configure-existing-proxmox.yml --tags api-tokens -e rotate_tokens=true

# View tokens from 1Password
proxmox-view-tokens:
    @op read "op://Homelab/Proxmox API Token/token_id" 2>/dev/null && op read "op://Homelab/Proxmox API Token/token_secret" 2>/dev/null || echo "Failed to read tokens from 1Password"

# --- TrueNAS ---

truenas-ping:
    cd ansible && ansible -i inventory.ini truenas -m ping

# Configure primary TrueNAS (datasets, shares, snapshots)
truenas-setup:
    cd ansible && ansible-playbook -i inventory.ini playbooks/truenas-setup.yml

# --- Molecule Tests ---

# Verify all hosts (Proxmox + TrueNAS)
verify-all:
    cd ansible && molecule verify

# Verify primary TrueNAS setup
truenas-verify:
    cd ansible && molecule verify -s truenas-setup

# Verify Proxmox node configuration (packages, SSH, passthrough, fan control)
proxmox-verify:
    cd ansible && molecule verify -s proxmox-configure

# Verify Proxmox networking (VLAN bridges, IPs, MTU, routing)
proxmox-verify-networking:
    cd ansible && molecule verify -s proxmox-networking

# Configure backup TrueNAS
truenas-backup-setup:
    cd ansible && ansible-playbook -i inventory.ini playbooks/truenas-backup-setup.yml

# Configure Proxmox Backup Server (post-install)
pbs-setup:
    cd ansible && ansible-playbook -i inventory.ini playbooks/pbs-setup.yml

# Setup ZFS replication (din -> grogu)
truenas-replication:
    cd ansible && ansible-playbook -i inventory.ini playbooks/truenas-replication.yml

# Set enclosure fan speeds (MD1200/MD1220)
enclosure-fan:
    cd ansible && ansible-playbook -i inventory.ini \
      playbooks/configure-existing-proxmox.yml --tags enclosure-fan

# --- Restic Backup (B2) ---

restic-setup:
    cd ansible && ansible-playbook -i inventory.ini playbooks/truenas-restic-backup.yml

# --- Terragrunt ---

tg-init:
    cd infrastructure && terragrunt run --all init

tg-plan:
    cd infrastructure && terragrunt run --all plan

tg-apply:
    cd infrastructure && terragrunt run --all apply

tg-destroy:
    cd infrastructure && terragrunt run --all destroy

tg-validate:
    cd infrastructure && terragrunt run --all validate

tg-fmt:
    cd infrastructure && terragrunt run --all fmt

tg-apply-module MODULE *ARGS:
    cd infrastructure/{{MODULE}} && terragrunt apply -auto-approve {{ARGS}}

tg-plan-module MODULE *ARGS:
    cd infrastructure/{{MODULE}} && terragrunt plan {{ARGS}}

tg-destroy-module MODULE *ARGS:
    cd infrastructure/{{MODULE}} && terragrunt destroy {{ARGS}}

tg-graph:
    cd infrastructure && terragrunt dag graph

tg-list:
    @find infrastructure -name "terragrunt.hcl" -not -path "*/.terragrunt-cache/*" | sed 's|infrastructure/||g' | sed 's|/terragrunt.hcl||g' | sort

# --- Kubernetes ---

# Clean up orphan ZFS datasets from destroyed/failed Talos VMs (VMIDs 4xx)
k8s-cleanup-zfs:
    #!/usr/bin/env bash
    set -euo pipefail
    for host in 192.168.0.11 192.168.0.10; do
        echo "Checking $(ssh root@$host hostname)..."
        ssh root@$host 'zfs list -H -o name | grep -E "vm-(4[0-9]{2})-" | while read ds; do
            vmid=$(echo "$ds" | sed "s/.*vm-\([0-9]*\)-.*/\1/")
            if ! qm status "$vmid" >/dev/null 2>&1; then
                echo "  Destroying orphan: $ds"
                zfs destroy "$ds"
            fi
        done' || true
    done

# --- Utilities ---

clean:
    rm -rf nix/result nix/result-*

lint:
    pre-commit run --all-files
