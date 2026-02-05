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
    for k, v in var.control_plane_nodes : k => {
      hostname = v.hostname
      node     = v.node_name
      vmid     = v.vm_id
      ip       = split("/", v.ip_address)[0]
    }
  }
}

output "worker_nodes" {
  description = "Worker node information"
  value = {
    for k, v in var.worker_nodes : k => {
      hostname = v.hostname
      node     = v.node_name
      vmid     = v.vm_id
      ip       = split("/", v.ip_address)[0]
      gpu      = v.gpu_passthrough
    }
  }
}

output "kubeconfig_path" {
  description = "Path to kubeconfig file"
  value       = var.deploy_bootstrap ? local_sensitive_file.kubeconfig[0].filename : null
}

output "talosconfig_path" {
  description = "Path to talosconfig file"
  value       = local_sensitive_file.talosconfig.filename
}

output "kubeconfig_raw" {
  description = "Raw kubeconfig content"
  value       = var.deploy_bootstrap ? talos_cluster_kubeconfig.cluster[0].kubeconfig_raw : null
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
