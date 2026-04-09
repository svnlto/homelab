# Flux Operator on shared cluster — GitOps via FluxCD.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

dependencies {
  paths = ["../k8s-shared"]
}

inputs = {
  kubeconfig_path       = "${get_terragrunt_dir()}/../k8s-shared/configs/kubeconfig-shared"
  namespace             = "flux-system"
  flux_operator_version = "0.43.0"
  flux_instance_version = "0.43.0"
  repo_url              = "https://github.com/svnlto/homelab"
  repo_branch           = "main"
  sync_path             = "kubernetes/flux/clusters/shared"
  ingress_host          = "flux.shared.h.svenlito.com"

  github_token = get_env("TF_VAR_github_token")
}
