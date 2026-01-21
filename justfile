default:
    @just --list

# =============================================================================
# Bare-Metal Proxmox Node (bootable images for physical servers)
# =============================================================================

bare-metal-vm-up:
    cd packer/bare-metal && vagrant up

bare-metal-vm-down:
    cd packer/bare-metal && vagrant halt

bare-metal-vm-destroy:
    cd packer/bare-metal && vagrant destroy -f

bare-metal-vm-ssh:
    cd packer/bare-metal && vagrant ssh

packer-build-bare-metal:
    @echo "Building bare-metal Proxmox VE image (15-20 min)..."
    cd packer/bare-metal && vagrant ssh -c "cd /vagrant && packer build -var 'output_format=raw' ."

bare-metal-images:
    @echo "Available bare-metal images:"
    @ls -lh packer/bare-metal/output/*/*.raw* 2>/dev/null || echo "No images found"

bare-metal-flash disk:
    @echo "Flashing bare-metal image to {{disk}}..."
    @IMAGE=$$(ls -t packer/bare-metal/output/*/*.raw.gz 2>/dev/null | head -1) && \
      if [ -z "$$IMAGE" ]; then echo "Error: No image found"; exit 1; fi && \
      echo "Using: $$IMAGE" && \
      gunzip -c "$$IMAGE" | sudo dd of={{disk}} bs=4M status=progress conv=fsync && \
      echo "✅ Done! Boot your server from {{disk}}"

# =============================================================================
# Pi-hole (Raspberry Pi ARM images)
# =============================================================================

pihole-vm-up:
    cd packer/pihole && vagrant up

pihole-vm-down:
    cd packer/pihole && vagrant halt

pihole-vm-destroy:
    cd packer/pihole && vagrant destroy -f

pihole-vm-ssh:
    cd packer/pihole && vagrant ssh

packer-build-pihole:
    @echo "Building Pi-hole image (30-60 min)..."
    cd packer/pihole && vagrant ssh -c "cd /vagrant && packer build ."

pihole-images:
    @ls -lh packer/pihole/output/*.img 2>/dev/null || echo "No images found"

pihole-flash disk:
    @IMAGE=$$(ls -t packer/pihole/output/*.img 2>/dev/null | head -1) && \
      if [ -z "$$IMAGE" ]; then echo "Error: No image found"; exit 1; fi && \
      sudo dd if="$$IMAGE" of={{disk}} bs=4M status=progress

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
# Terraform VM Deployment (clones from VM template)
# =============================================================================

tf-init:
    cd terraform/proxmox && terraform init -upgrade

tf-validate:
    cd terraform/proxmox && terraform validate

tf-plan:
    cd terraform/proxmox && ANSIBLE_CONFIG="{{justfile_directory()}}/ansible/ansible.cfg" terraform plan

tf-apply:
    cd terraform/proxmox && ANSIBLE_CONFIG="{{justfile_directory()}}/ansible/ansible.cfg" terraform apply -auto-approve

tf-destroy:
    cd terraform/proxmox && terraform destroy -auto-approve

# =============================================================================
# TrueNAS Management
# =============================================================================

truenas-deploy:
    cd terraform/proxmox && terraform apply -target=proxmox_virtual_environment_download_file.truenas_iso -target=proxmox_virtual_environment_vm.truenas -auto-approve
    @echo "\n✅ TrueNAS VM created (ID: 300, IP: 192.168.1.76)"
    @echo "   Open Proxmox console and follow installation wizard"
    @echo "   Web UI after install: https://192.168.1.76"

truenas-destroy:
    cd terraform/proxmox && terraform destroy -target=proxmox_virtual_environment_vm.truenas -auto-approve

# =============================================================================
# Ansible
# =============================================================================

ansible-lint:
    ANSIBLE_CONFIG=ansible/ansible.cfg ansible-lint -c .ansible-lint.yaml ansible/

ansible-playbook PLAYBOOK:
    cd ansible && ansible-playbook playbooks/{{PLAYBOOK}}

# =============================================================================
# Utilities
# =============================================================================

clean:
    rm -rf packer/*/output/
    rm -rf packer/*/.packer_cache/
