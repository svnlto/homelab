# ArgoCD on shared cluster — GitOps hub.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

dependencies {
  paths = ["../k8s-shared"]
}

locals {
  global_vars = read_terragrunt_config(find_in_parent_folders("globals.hcl"))
}

inputs = {
  kubeconfig_path      = "${get_terragrunt_dir()}/../k8s-shared/configs/kubeconfig-shared"
  argocd_namespace     = "argocd"
  argocd_chart_version = "7.7.18"
  repo_url             = "https://github.com/svnlto/homelab"
  repo_branch          = "main"
  root_app_path        = "kubernetes/argocd-apps"

  # TODO: Generate a secure password and store in 1Password
  admin_password  = "changeme-ArgoCD-2024"
  server_service_type = "LoadBalancer"
  ingress_enabled     = false
  ingress_host    = ""
  spoke_clusters  = {}
}
