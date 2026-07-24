output "namespace" {
  description = "Namespace where the flux-operator and Flux controllers are installed"
  value       = kubernetes_namespace_v1.flux_system.metadata[0].name
}

output "operator_chart_version" {
  description = "Installed flux-operator Helm chart version"
  value       = var.operator_chart_version
}

output "flux_version" {
  description = "Flux distribution version range the operator reconciles to"
  value       = var.flux_version
}

output "sync" {
  description = "Fleet sync source the FluxInstance bootstraps"
  value = {
    url  = var.repo_url
    ref  = var.repo_ref
    path = var.sync_path
  }
}
