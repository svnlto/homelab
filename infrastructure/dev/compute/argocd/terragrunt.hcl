# ==============================================================================
# ArgoCD Deployment - Test Cluster (Hub)
# ==============================================================================
# Deploys ArgoCD on test cluster to manage all clusters via hub-and-spoke
# Test cluster will later become shared-services cluster

include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Dependency on test-cluster (must exist first)
dependency "test_cluster" {
  config_path = "../test-cluster"
}

locals {
  global_vars = read_terragrunt_config(find_in_parent_folders("globals.hcl"))
}

inputs = {
  # Kubeconfig from test-cluster deployment
  kubeconfig_path = "${get_terragrunt_dir()}/../test-cluster/configs/kubeconfig-test"

  # ArgoCD configuration
  argocd_namespace     = "argocd"
  argocd_chart_version = "7.7.18" # ArgoCD Helm chart version

  # Git repository for App of Apps
  repo_url    = "https://github.com/svnlto/homelab"
  repo_branch = "main"

  # Path to ArgoCD Application manifests
  root_app_path = "kubernetes/argocd-apps"

  # Initial admin password (stored in 1Password)
  # TODO: Generate a secure password and store in 1Password
  admin_password = "changeme-ArgoCD-2024"

  # Ingress disabled for now (use port-forward)
  ingress_enabled = false
  ingress_host    = ""

  # Spoke clusters (empty for now, will add prod/shared-services later)
  spoke_clusters = {}
}
