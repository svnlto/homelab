variable "kubeconfig_path" {
  description = "Path to kubeconfig file for the cluster"
  type        = string
}

variable "namespace" {
  description = "Namespace for Flux controllers"
  type        = string
}

variable "flux_operator_version" {
  description = "Flux Operator Helm chart version"
  type        = string
}

variable "flux_instance_version" {
  description = "Flux Instance Helm chart version"
  type        = string
}

variable "github_token" {
  description = "GitHub PAT for repo access and image automation push"
  type        = string
  sensitive   = true
}

variable "repo_url" {
  description = "Git repository URL"
  type        = string
}

variable "repo_branch" {
  description = "Git branch to track"
  type        = string
}

variable "sync_path" {
  description = "Path in Git repo for FluxInstance sync entry point"
  type        = string
}

variable "ingress_host" {
  description = "Hostname for Flux web UI ingress"
  type        = string
}
