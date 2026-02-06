variable "kubeconfig_path" {
  description = "Path to kubeconfig file for hub cluster"
  type        = string
}

variable "argocd_namespace" {
  description = "Namespace to install ArgoCD"
  type        = string
  default     = "argocd"
}

variable "argocd_chart_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "7.7.18"
}

variable "repo_url" {
  description = "Git repository URL for App of Apps pattern"
  type        = string
}

variable "repo_branch" {
  description = "Git branch to track"
  type        = string
  default     = "main"
}

variable "root_app_path" {
  description = "Path in Git repo containing ArgoCD Application manifests"
  type        = string
  default     = "kubernetes/argocd-apps"
}

variable "admin_password" {
  description = "Initial ArgoCD admin password (change after first login)"
  type        = string
  sensitive   = true
}

variable "ingress_enabled" {
  description = "Enable ingress for ArgoCD UI"
  type        = bool
  default     = false
}

variable "ingress_host" {
  description = "Hostname for ArgoCD UI ingress"
  type        = string
  default     = ""
}

variable "spoke_clusters" {
  description = "Map of spoke clusters to register with ArgoCD"
  type = map(object({
    server      = string # Kubernetes API server URL
    ca_data     = string # Base64 encoded CA certificate
    cert_data   = string # Base64 encoded client certificate
    key_data    = string # Base64 encoded client key
    description = string # Cluster description
  }))
  default = {}
}
