variable "kubeconfig_path" {
  description = "Path to kubeconfig file for the target cluster"
  type        = string
}

variable "namespace" {
  description = "Namespace to install the flux-operator and Flux controllers"
  type        = string
  default     = "flux-system"
}

variable "operator_chart_version" {
  description = "flux-operator Helm chart version (tracks the operator release)"
  type        = string
  default     = "0.56.0"
}

variable "flux_version" {
  description = "Flux distribution version range the operator installs (pin a range, never latest)"
  type        = string
  default     = "2.9.x"
}

variable "flux_components" {
  description = "Flux controllers to install"
  type        = list(string)
  default = [
    "source-controller",
    "kustomize-controller",
    "helm-controller",
    "notification-controller",
  ]
}

variable "cluster_size" {
  description = "Resource preset for the Flux controllers (small | medium | large)"
  type        = string
  default     = "small"
}

variable "multitenant" {
  description = "Enable multi-tenancy lockdown. Keep false while HelmReleases reference the flux-system GitRepository cross-namespace."
  type        = bool
  default     = false
}

variable "repo_url" {
  description = "Git repository URL the FluxInstance syncs the fleet from"
  type        = string
}

variable "repo_ref" {
  description = "Git ref the FluxInstance tracks (e.g. refs/heads/main)"
  type        = string
  default     = "refs/heads/main"
}

variable "sync_path" {
  description = "Path in the repo containing the root Flux Kustomization set"
  type        = string
  default     = "kubernetes/apps/_flux"
}
