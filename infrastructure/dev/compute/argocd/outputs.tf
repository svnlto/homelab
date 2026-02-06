output "argocd_namespace" {
  description = "Namespace where ArgoCD is installed"
  value       = module.argocd.argocd_namespace
}

output "argocd_server_url" {
  description = "ArgoCD server URL"
  value       = module.argocd.argocd_server_url
}

output "argocd_initial_admin_password" {
  description = "Initial ArgoCD admin password"
  value       = module.argocd.argocd_initial_admin_password
  sensitive   = true
}

output "root_app_status" {
  description = "Root Application status"
  value       = module.argocd.root_app_status
}

output "registered_clusters" {
  description = "List of registered spoke clusters"
  value       = module.argocd.registered_clusters
}
