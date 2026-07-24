# Flux Operator on shared cluster — manages the Flux distribution (FluxInstance).

terraform {
  source = "${get_repo_root()}/infrastructure/modules//flux-operator"
}

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
  kubeconfig_path = "${get_terragrunt_dir()}/../k8s-shared/configs/kubeconfig-shared"
  namespace       = "flux-system"

  operator_chart_version = "0.56.0"
  flux_version           = "2.9.x"
  cluster_size           = "small"
  multitenant            = false

  repo_url = "https://github.com/svnlto/homelab"
  # Tracks main (migration complete).
  repo_ref  = "refs/heads/main"
  sync_path = "kubernetes/apps/_flux"
}
