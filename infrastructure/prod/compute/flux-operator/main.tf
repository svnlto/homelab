module "flux_operator" {
  source = "../../../modules/flux-operator"

  kubeconfig_path       = var.kubeconfig_path
  namespace             = var.namespace
  flux_operator_version = var.flux_operator_version
  flux_instance_version = var.flux_instance_version
  github_token          = var.github_token
  repo_url              = var.repo_url
  repo_branch           = var.repo_branch
  sync_path             = var.sync_path
  ingress_host          = var.ingress_host
}
