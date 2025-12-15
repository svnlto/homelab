# Proxmox Ubuntu Template with Packer + Ansible

This directory contains Packer configuration to build an Ubuntu 24.04 LTS VM template on Proxmox VE.

## Overview

**Golden Image Workflow:**

```text
Ubuntu ISO → Packer (autoinstall) → Ansible (provisioning) → Proxmox Template → Terraform (clone)
```

**Benefits:**

- Fast VM deployment (clone in seconds vs 20+ min install)
- Consistent base configuration across all VMs
- Infrastructure as Code for the entire stack
- Easy updates (rebuild template, redeploy VMs)

## Best Practices Implemented

### VM Template Configuration

- ✅ **UEFI (OVMF)** - Modern BIOS, required for Secure Boot
- ✅ **Q35 machine type** - Modern chipset emulation
- ✅ **VirtIO drivers** - Best performance (SCSI, network, GPU)
- ✅ **Cloud-Init enabled** - Automated VM customization on clone
- ✅ **QEMU Guest Agent** - Better VM management
- ✅ **Thin provisioning** - Disk space efficiency
- ✅ **TRIM/discard** - SSD optimization

### Security Hardening (via Ansible)

- ✅ SSH hardening (no root login, key-only auth)
- ✅ Firewall configured (UFW, disabled by default)
- ✅ Automatic security updates (unattended-upgrades)
- ✅ Minimal attack surface
- ✅ Machine ID cleared (unique per clone)

### System Optimization

- ✅ Essential packages pre-installed
- ✅ System tuning (sysctl parameters)
- ✅ Logging configured
- ✅ Python for Ansible ready

## Prerequisites

### 1. Proxmox API Token

Create an API token for Packer:

```bash
# On Proxmox web UI:
# Datacenter → Permissions → API Tokens → Add

# Or via CLI on Proxmox host:
pveum user token add root@pam terraform -privsep 0
```

**Save the output:**

```text
TOKEN_ID: root@pam!terraform
TOKEN_SECRET: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

### 2. Environment Variables

```bash
export PROXMOX_TOKEN_ID="root@pam!terraform"
export PROXMOX_TOKEN_SECRET="your-token-secret-here"

# If using 1Password for SSH keys
export SSH_AUTH_SOCK="$HOME/.1password/agent.sock"
```

### 3. Upload Ubuntu ISO to Proxmox

```bash
# Download Ubuntu 24.04 LTS
wget https://releases.ubuntu.com/noble/ubuntu-24.04.3-live-server-amd64.iso

# Upload to Proxmox
scp ubuntu-24.04.3-live-server-amd64.iso root@192.168.1.37:/var/lib/vz/template/iso/
```

### 4. Install Packer and Ansible

Using Nix (recommended):

```bash
nix develop  # From project root
```

Or install manually:

```bash
# macOS
brew install packer ansible

# Ubuntu
sudo apt install packer ansible
```

## Building the Template

### Step 1: Validate Configuration

```bash
cd packer/proxmox-ubuntu-template
packer validate ubuntu-24.04-template.pkr.hcl
```

### Step 2: Build Template

```bash
# Build template (takes ~15-30 minutes)
packer build ubuntu-24.04-template.pkr.hcl
```

**What happens:**

1. Packer creates a VM (ID: 9000) on Proxmox
2. Boots from Ubuntu ISO with automated install (autoinstall)
3. Waits for installation to complete
4. Runs system updates
5. Installs base packages
6. Runs Ansible playbook for provisioning
7. Cleans up (cloud-init, logs, machine ID)
8. Converts VM to template

### Step 3: Verify Template

```bash
# On Proxmox web UI:
# Navigate to VM 9000 - should show as "Template"

# Or via CLI on Proxmox:
qm list | grep 9000
```

## Using the Template

### Option 1: Terraform (Recommended)

See `terraform/proxmox/` for full configuration.

```bash
cd ../../terraform/proxmox

# Use template configuration
mv main.tf main-iso.tf.bak
mv main-from-template.tf main.tf

# Configure
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars

# Deploy
terraform init
terraform plan
terraform apply
```

**Example terraform.tfvars:**

```hcl
proxmox_password = "your-password"
template_name    = "ubuntu-24.04-cloudimg-template"
vm_name          = "test-vm-01"
vm_cores         = 4
vm_memory        = 8192
vm_disk_size     = "50G"

# Cloud-Init configuration
# Get your public key from 1Password: ssh-add -L | head -1
ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA..."
vm_ipconfig    = "ip=192.168.1.150/24,gw=192.168.1.1"
vm_nameserver  = "192.168.1.2"
```

### Option 2: Proxmox CLI

```bash
# Clone template
qm clone 9000 100 --name my-vm --full

# Configure cloud-init
qm set 100 --ipconfig0 ip=192.168.1.100/24,gw=192.168.1.1
qm set 100 --nameserver 192.168.1.2
qm set 100 --sshkey ~/.ssh/id_rsa.pub

# Start VM
qm start 100
```

### Option 3: Proxmox Web UI

1. Navigate to template VM (9000)
2. Right-click → Clone
3. Mode: Full Clone
4. VM ID: (choose available)
5. Name: my-vm
6. Click "Clone"
7. Edit cloned VM → Cloud-Init tab
8. Configure IP, SSH keys, etc.
9. Start VM

## Post-Deployment with Ansible

After cloning, use Ansible to configure VM-specific settings:

```bash
cd ../../ansible

# Create inventory
cat > inventory.yml <<EOF
all:
  hosts:
    test-vm:
      ansible_host: 192.168.1.150
      ansible_user: ubuntu
EOF

# Run VM-specific playbook
ansible-playbook -i inventory.yml playbooks/configure-web-server.yml
```

## Customization

### Modify Template Configuration

Edit `ubuntu-24.04-template.pkr.hcl`:

```hcl
# Change VM resources
cores  = 4
memory = 8192

# Change disk size
disk_size = "50G"

# Change storage pool
storage_pool = "nvme-pool"
```

### Modify Base Provisioning

Edit `../../ansible/playbooks/base-vm.yml`:

```yaml
# Add packages
base_packages:
  - vim
  - your-package-here

# Add tasks
tasks:
  - name: Your custom task
    shell: echo "hello"
```

### Autoinstall Configuration

Edit `http/user-data` for installation customization:

```yaml
autoinstall:
  # Change partitioning
  storage:
    layout:
      name: lvm  # or 'direct' for no LVM

  # Add packages
  packages:
    - your-package
```

## Rebuilding the Template

To update the template with new changes:

```bash
# Method 1: Delete old template and rebuild
qm destroy 9000
packer build ubuntu-24.04-template.pkr.hcl

# Method 2: Use different VM ID
# Edit ubuntu-24.04-template.pkr.hcl:
#   vm_id = 9001
packer build ubuntu-24.04-template.pkr.hcl
```

## Troubleshooting

### Packer Build Fails

**Check Packer logs:**

```bash
export PACKER_LOG=1
packer build ubuntu-24.04-template.pkr.hcl
```

**Common issues:**

- API token incorrect: verify `PROXMOX_TOKEN_ID` and `PROXMOX_TOKEN_SECRET`
- ISO not found: check `/var/lib/vz/template/iso/` on Proxmox
- Storage pool doesn't exist: verify with `pvesm status` on Proxmox
- VM ID already exists: change `vm_id` variable

### Autoinstall Hangs

**Check HTTP server:**
Packer runs a temporary HTTP server for cloud-init files. Check:

- Firewall allows connection from Proxmox to your machine
- Files in `http/` directory are readable

**View console:**
Open Proxmox web UI → VM → Console to see installation progress

### Ansible Provisioning Fails

**Test connectivity:**

```bash
# After VM boots, test SSH
ssh ubuntu@<vm-ip>
```

**Run Ansible manually:**

```bash
ansible-playbook -i "<vm-ip>," -u ubuntu ../../ansible/playbooks/base-vm.yml
```

### Template Won't Clone

**Verify template status:**

```bash
# On Proxmox
qm status 9000
# Should show "template" in status
```

**Check cloud-init:**

```bash
qm cloudinit dump 9000 user
```

## Template Maintenance

### Update Template Monthly

```bash
# Rebuild with latest updates
packer build ubuntu-24.04-template.pkr.hcl

# Test by cloning
qm clone 9000 999 --name test-template
qm start 999

# If good, destroy old VMs and redeploy from new template
```

### Version Control Templates

Consider version-tagged templates:

```hcl
variable "template_name" {
  default = "ubuntu-24.04-cloudimg-template-v2.0"
}
```

## Integration with Homelab

This template integrates with your existing homelab:

**DNS:** Pre-configured to use Pi-hole (`192.168.1.2`)
**VPN:** Access via Tailscale through subnet router (`192.168.1.100`)
**Storage:** Ready to mount Unraid shares (`192.168.1.20`)

## Next Steps

1. **Build the template** (15-30 min)
2. **Test clone with Terraform** (2-3 min)
3. **Create VM-specific Ansible playbooks**
4. **Deploy your applications!**

## Example Use Cases

### Web Server VM

```bash
terraform apply -var="vm_name=web-01" -var="vm_cores=2" -var="vm_memory=4096"
ansible-playbook -i inventory.yml playbooks/nginx.yml
```

### Database VM

```bash
terraform apply -var="vm_name=db-01" -var="vm_cores=4" -var="vm_memory=16384"
ansible-playbook -i inventory.yml playbooks/postgresql.yml
```

### Development VM

```bash
terraform apply -var="vm_name=dev-01" -var="vm_cores=8" -var="vm_memory=32768"
ansible-playbook -i inventory.yml playbooks/dev-tools.yml
```

## Resources

- [Packer Proxmox Builder](https://developer.hashicorp.com/packer/integrations/hashicorp/proxmox/latest/components/builder/iso)
- [Ubuntu Autoinstall](https://ubuntu.com/server/docs/install/autoinstall)
- [Proxmox Cloud-Init](https://pve.proxmox.com/wiki/Cloud-Init_Support)
- [Ansible Documentation](https://docs.ansible.com/)
