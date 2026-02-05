# ==============================================================================
# Dev Test Cluster - Outputs
# ==============================================================================

output "cluster_name" {
  description = "Name of the Kubernetes cluster"
  value       = module.test_cluster.cluster_name
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint"
  value       = module.test_cluster.cluster_endpoint
}

output "control_plane_nodes" {
  description = "Control plane node information"
  value       = module.test_cluster.control_plane_nodes
}

output "worker_nodes" {
  description = "Worker node information"
  value       = module.test_cluster.worker_nodes
}

output "kubeconfig_path" {
  description = "Path to kubeconfig file"
  value       = module.test_cluster.kubeconfig_path
}

output "talosconfig_path" {
  description = "Path to talosconfig file"
  value       = module.test_cluster.talosconfig_path
}

output "kubeconfig_raw" {
  description = "Raw kubeconfig content"
  value       = module.test_cluster.kubeconfig_raw
  sensitive   = true
}
