module "argocd" {
  source = "../../../modules/argocd"

  kubeconfig_path      = var.kubeconfig_path
  argocd_namespace     = var.argocd_namespace
  argocd_chart_version = var.argocd_chart_version
  repo_url             = var.repo_url
  repo_branch          = var.repo_branch
  root_app_path        = var.root_app_path
  admin_password       = var.admin_password
  server_service_type  = var.server_service_type
  ingress_enabled      = var.ingress_enabled
  ingress_host         = var.ingress_host
  spoke_clusters       = var.spoke_clusters
}
