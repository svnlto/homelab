# ==============================================================================
# Proxmox Network Bridge Configuration
# ==============================================================================
# This Terraform configuration triggers Ansible to configure network bridges
# on Proxmox hosts for Kubernetes clusters.
#
# Note: Proxmox host networking cannot be configured directly via Terraform.
# Instead, we use a null_resource to trigger an Ansible playbook.
#
# What it configures:
#   - vmbr10 (VLAN 10 - Storage)
#   - vmbr20 (VLAN 20 - LAN/Management)
#   - vmbr30 (VLAN 30 - K8s Shared Services)
#   - vmbr31 (VLAN 31 - K8s Apps)
#   - vmbr32 (VLAN 32 - K8s Test)
#
# Manual trigger:
#   terraform apply -target=null_resource.proxmox_networking
#
# Or use justfile command:
#   just proxmox-configure-networking
# ==============================================================================

resource "null_resource" "proxmox_networking" {
  # Trigger re-run when network configuration changes
  triggers = {
    # Update this timestamp to force re-run
    config_version = "2024-02-02-k8s-vlans"

    # Trigger on network config changes
    vlans = join(",", [
      local.vlan_storage,
      local.vlan_lan,
      local.vlan_k8s_shared,
      local.vlan_k8s_apps,
      local.vlan_k8s_test
    ])
  }

  # Wait for Proxmox hosts to be accessible
  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for Proxmox hosts to be accessible..."
      timeout 60 bash -c 'until nc -z ${local.ip_grogu_mgmt} 22; do sleep 2; done'
      timeout 60 bash -c 'until nc -z ${local.ip_din_mgmt} 22; do sleep 2; done'
      echo "Proxmox hosts are accessible"
    EOT
  }

  # Run Ansible playbook to configure networking
  provisioner "local-exec" {
    command = <<-EOT
      cd ${path.module}/../ansible
      ansible-playbook playbooks/configure-proxmox-networking.yml \
        --inventory inventory.ini \
        --extra-vars "gateway_ip=${local.ip_gateway}"
    EOT
  }

  # Show success message
  provisioner "local-exec" {
    when    = create
    command = <<-EOT
      echo ""
      echo "================================================================================"
      echo "Proxmox network bridges configured successfully!"
      echo "================================================================================"
      echo ""
      echo "Configured bridges:"
      echo "  vmbr10 (VLAN 10 - Storage):           grogu: ${local.ip_grogu_storage}, din: ${local.ip_din_storage}"
      echo "  vmbr20 (VLAN 20 - LAN/Management):    grogu: ${local.ip_grogu_mgmt}, din: ${local.ip_din_mgmt}"
      echo "  vmbr30 (VLAN 30 - K8s Shared):        No IP (VMs only)"
      echo "  vmbr31 (VLAN 31 - K8s Apps):          No IP (VMs only)"
      echo "  vmbr32 (VLAN 32 - K8s Test):          No IP (VMs only)"
      echo ""
      echo "Next steps:"
      echo "  1. Verify Proxmox web UI: https://${local.ip_grogu_mgmt}:8006"
      echo "  2. Deploy Kubernetes clusters: just tf-apply"
      echo ""
      echo "================================================================================"
    EOT
  }
}

# Output for reference
output "proxmox_networking_status" {
  value = {
    grogu = {
      management_ip = local.ip_grogu_mgmt
      storage_ip    = local.ip_grogu_storage
      idrac_ip      = local.ip_grogu_idrac
    }
    din = {
      management_ip = local.ip_din_mgmt
      storage_ip    = local.ip_din_storage
      idrac_ip      = local.ip_din_idrac
    }
    bridges = {
      vmbr10 = "VLAN ${local.vlan_storage} (Storage)"
      vmbr20 = "VLAN ${local.vlan_lan} (LAN/Management)"
      vmbr30 = "VLAN ${local.vlan_k8s_shared} (K8s Shared Services)"
      vmbr31 = "VLAN ${local.vlan_k8s_apps} (K8s Apps)"
      vmbr32 = "VLAN ${local.vlan_k8s_test} (K8s Test)"
    }
  }
  description = "Proxmox networking configuration status"
}
