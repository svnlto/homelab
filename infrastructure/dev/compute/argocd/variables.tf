variable "kubeconfig_path" {
  description = "Path to kubeconfig file for hub cluster"
  type        = string
}

variable "argocd_namespace" {
  description = "Namespace to install ArgoCD"
  type        = string
}

variable "argocd_chart_version" {
  description = "ArgoCD Helm chart version"
  type        = string
}

variable "repo_url" {
  description = "Git repository URL for App of Apps pattern"
  type        = string
}

variable "repo_branch" {
  description = "Git branch to track"
  type        = string
}

variable "root_app_path" {
  description = "Path in Git repo containing ArgoCD Application manifests"
  type        = string
}

variable "admin_password" {
  description = "Initial ArgoCD admin password"
  type        = string
  sensitive   = true
}

variable "ingress_enabled" {
  description = "Enable ingress for ArgoCD UI"
  type        = bool
}

variable "ingress_host" {
  description = "Hostname for ArgoCD UI ingress"
  type        = string
}

variable "spoke_clusters" {
  description = "Map of spoke clusters to register"
  type = map(object({
    server      = string
    ca_data     = string
    cert_data   = string
    key_data    = string
    description = string
  }))
}
