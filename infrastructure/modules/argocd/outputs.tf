output "argocd_namespace" {
  description = "Namespace where ArgoCD is installed"
  value       = kubernetes_namespace.argocd.metadata[0].name
}

output "argocd_server_url" {
  description = "ArgoCD server URL (use port-forward if ingress disabled)"
  value       = var.ingress_enabled ? "https://${var.ingress_host}" : "Port-forward required: kubectl port-forward svc/argocd-server -n argocd 8080:443"
}

output "argocd_initial_admin_password" {
  description = "Initial ArgoCD admin password (CHANGE AFTER FIRST LOGIN)"
  value       = var.admin_password
  sensitive   = true
}

output "root_app_status" {
  description = "Root Application (App of Apps) created"
  value = {
    name      = "root"
    repo_url  = var.repo_url
    repo_path = var.root_app_path
    branch    = var.repo_branch
    deployed  = null_resource.root_app.id != "" ? true : false
  }
}

output "registered_clusters" {
  description = "List of registered spoke clusters"
  value       = keys(var.spoke_clusters)
}
