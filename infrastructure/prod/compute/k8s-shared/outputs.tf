# ==============================================================================
# Prod Shared Cluster - Outputs
# ==============================================================================

output "cluster_name" {
  description = "Name of the Kubernetes cluster"
  value       = module.k8s_shared.cluster_name
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint"
  value       = module.k8s_shared.cluster_endpoint
}

output "control_plane_nodes" {
  description = "Control plane node information"
  value       = module.k8s_shared.control_plane_nodes
}

output "worker_nodes" {
  description = "Worker node information"
  value       = module.k8s_shared.worker_nodes
}

output "kubeconfig_path" {
  description = "Path to kubeconfig file"
  value       = module.k8s_shared.kubeconfig_path
}

output "talosconfig_path" {
  description = "Path to talosconfig file"
  value       = module.k8s_shared.talosconfig_path
}

output "kubeconfig_raw" {
  description = "Raw kubeconfig content"
  value       = module.k8s_shared.kubeconfig_raw
  sensitive   = true
}

output "traefik_tailscale_ip" {
  description = "Tailscale IP assigned to Traefik"
  value       = module.k8s_shared.traefik_tailscale_ip
}
