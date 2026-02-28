output "namespace" {
  description = "Namespace where Flux controllers are installed"
  value       = kubernetes_namespace_v1.flux_system.metadata[0].name
}

output "web_ui_url" {
  description = "Flux web UI URL"
  value       = var.ingress_host != "" ? "https://${var.ingress_host}" : "Port-forward required: kubectl port-forward svc/flux-operator -n flux-system 9080:80"
}

output "sync_path" {
  description = "Git repository path used for FluxInstance sync"
  value       = var.sync_path
}
