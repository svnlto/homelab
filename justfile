default:
    @just --list

# ARM Builder (Pi-hole)

arm-vm-up:
    cd packer/arm-builder && just vm-up

arm-vm-down:
    cd packer/arm-builder && just vm-down

arm-vm-destroy:
    cd packer/arm-builder && just vm-destroy

arm-vm-ssh:
    cd packer/arm-builder && just vm-ssh

packer-build-pihole:
    cd packer/arm-builder && just build

pihole-images:
    cd packer/arm-builder && just images

pihole-flash disk:
    cd packer/arm-builder && just flash {{disk}}

# x86 Builder (Bootable Disk Images)

x86-vm-up:
    cd packer/x86-builder && just vm-up

x86-vm-down:
    cd packer/x86-builder && just vm-down

x86-vm-destroy:
    cd packer/x86-builder && just vm-destroy

x86-vm-ssh:
    cd packer/x86-builder && just vm-ssh

x86-build:
    cd packer/x86-builder && just build

x86-images:
    cd packer/x86-builder && just images

x86-deploy disk:
    cd packer/x86-builder && just deploy {{disk}}

# Proxmox Template Building

packer-init-proxmox:
    cd packer/proxmox-templates && packer init ubuntu-24.04-template.pkr.hcl

packer-validate-proxmox:
    cd packer/proxmox-templates && packer validate ubuntu-24.04-template.pkr.hcl

packer-build-proxmox:
    cd packer/proxmox-templates && packer init ubuntu-24.04-template.pkr.hcl && packer build ubuntu-24.04-template.pkr.hcl

# Terraform VM Deployment
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

# TrueNAS Management

truenas-deploy:
    cd terraform/proxmox && terraform apply -target=proxmox_virtual_environment_download_file.truenas_iso -target=proxmox_virtual_environment_vm.truenas -auto-approve
    @echo "\n✅ TrueNAS VM created (ID: 300, IP: 192.168.1.76)"
    @echo "   Open Proxmox console and follow installation wizard"
    @echo "   Web UI after install: https://192.168.1.76"

truenas-destroy:
    cd terraform/proxmox && terraform destroy -target=proxmox_virtual_environment_vm.truenas -auto-approve

# Ansible
ansible-lint:
    ANSIBLE_CONFIG=ansible/ansible.cfg ansible-lint -c .ansible-lint.yaml ansible/

ansible-playbook PLAYBOOK:
    cd ansible && ansible-playbook playbooks/{{PLAYBOOK}}

# Utilities
clean:
    rm -rf output/
