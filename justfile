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
    @op read "op://Personal/Proxmox API Token/token_id" 2>/dev/null && op read "op://Personal/Proxmox API Token/token_secret" 2>/dev/null || echo "Failed to read tokens from 1Password"

# --- TrueNAS ---

truenas-ping:
    cd ansible && ansible -i inventory.ini truenas -m ping

# Configure primary TrueNAS (datasets, shares, snapshots)
truenas-setup:
    cd ansible && ansible-playbook -i inventory.ini playbooks/truenas-setup.yml

# Configure backup TrueNAS
truenas-backup-setup:
    cd ansible && ansible-playbook -i inventory.ini playbooks/truenas-backup-setup.yml

# Setup ZFS replication (din -> grogu)
truenas-replication:
    cd ansible && ansible-playbook -i inventory.ini playbooks/truenas-replication.yml

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

tg-apply-module MODULE:
    cd infrastructure/{{MODULE}} && terragrunt apply

tg-plan-module MODULE:
    cd infrastructure/{{MODULE}} && terragrunt plan

tg-destroy-module MODULE:
    cd infrastructure/{{MODULE}} && terragrunt destroy

tg-graph:
    cd infrastructure && terragrunt dag graph

tg-list:
    @find infrastructure -name "terragrunt.hcl" -not -path "*/.terragrunt-cache/*" | sed 's|infrastructure/||g' | sed 's|/terragrunt.hcl||g' | sort

# --- Utilities ---

clean:
    rm -rf nix/result nix/result-*

lint:
    pre-commit run --all-files
