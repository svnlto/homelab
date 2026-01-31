# ==============================================================================
# Talos Cluster Module - Outputs
# ==============================================================================

output "cluster_name" {
  description = "Talos cluster name"
  value       = var.cluster_name
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint (VIP)"
  value       = var.cluster_endpoint
}

output "vip_ip" {
  description = "Virtual IP for HA control plane"
  value       = var.vip_ip
}

output "schematic_id" {
  description = "Talos Image Factory schematic ID"
  value       = talos_image_factory_schematic.this.id
}

output "talos_version" {
  description = "Talos Linux version"
  value       = var.talos_version
}

output "kubernetes_version" {
  description = "Kubernetes version"
  value       = var.kubernetes_version
}

output "control_plane_nodes" {
  description = "Control plane node information"
  value = {
    for k, v in proxmox_virtual_environment_vm.control_plane : k => {
      hostname = v.name
      node     = v.node_name
      vmid     = v.vm_id
      ip       = split("/", v.initialization[0].ip_config[0].ipv4[0].address)[0]
    }
  }
}

output "worker_nodes" {
  description = "Worker node information"
  value = {
    for k, v in proxmox_virtual_environment_vm.worker : k => {
      hostname = v.name
      node     = v.node_name
      vmid     = v.vm_id
      ip       = split("/", v.initialization[0].ip_config[0].ipv4[0].address)[0]
      gpu      = contains(v.tags, "gpu")
    }
  }
}

output "kubeconfig_path" {
  description = "Path to kubeconfig file"
  value       = local_sensitive_file.kubeconfig.filename
}

output "talosconfig_path" {
  description = "Path to talosconfig file"
  value       = local_sensitive_file.talosconfig.filename
}

output "kubeconfig_raw" {
  description = "Raw kubeconfig content"
  value       = talos_cluster_kubeconfig.cluster.kubeconfig_raw
  sensitive   = true
}

output "talosconfig_raw" {
  description = "Raw talosconfig content"
  value       = data.talos_client_configuration.talosconfig.talos_config
  sensitive   = true
}

output "client_configuration" {
  description = "Talos client configuration for talosctl"
  value       = talos_machine_secrets.cluster.client_configuration
  sensitive   = true
}

output "bootstrap_deployed" {
  description = "Whether bootstrap components were deployed"
  value       = var.deploy_bootstrap
}
