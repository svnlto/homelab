# ArgoCD Module

Reusable Terraform module for deploying ArgoCD on a hub cluster using the hub-and-spoke architecture.

## Features

- ✅ Deploys ArgoCD via Helm chart
- ✅ Creates root Application (App of Apps pattern)
- ✅ Registers spoke clusters for multi-cluster management
- ✅ Supports Kustomize overlays for per-cluster customization
- ✅ GitOps-based continuous deployment
- ✅ Metrics and monitoring enabled

## Usage

```hcl
module "argocd" {
  source = "../../../modules/argocd"

  # Kubeconfig for hub cluster
  kubeconfig_path = "/path/to/kubeconfig"

  # ArgoCD configuration
  argocd_namespace     = "argocd"
  argocd_chart_version = "7.7.18"

  # Git repository
  repo_url    = "https://github.com/username/homelab"
  repo_branch = "main"

  # Path to ArgoCD Application manifests
  root_app_path = "kubernetes/argocd-apps"

  # Admin credentials
  admin_password = "changeme"

  # Spoke clusters (optional)
  spoke_clusters = {
    prod = {
      server      = "https://prod-cluster:6443"
      ca_data     = base64encode(file("prod-ca.crt"))
      cert_data   = base64encode(file("prod-client.crt"))
      key_data    = base64encode(file("prod-client.key"))
      description = "Production cluster"
    }
  }
}
```

## Hub-and-Spoke Architecture

```
┌─────────────────────────────────┐
│      Hub Cluster (ArgoCD)       │
│                                 │
│  Manages applications across:   │
│  - Self (hub cluster)          │
│  - Spoke clusters              │
└─────────────────────────────────┘
         │         │         │
         ▼         ▼         ▼
    ┌────────┐ ┌──────┐ ┌──────┐
    │  Self  │ │ Prod │ │ Dev  │
    └────────┘ └──────┘ └──────┘
```

## App of Apps Pattern

The module creates a root Application that watches `kubernetes/argocd-apps/` directory in your Git repository. Any Application manifests in that directory are automatically deployed.

**Example directory structure:**

```
kubernetes/
├── argocd-apps/              # ArgoCD Applications (watched by root app)
│   ├── whoami-test.yaml
│   ├── whoami-prod.yaml
│   └── forgejo-shared.yaml
└── apps/                     # Kustomize manifests
    └── whoami/
        ├── base/             # Common manifests
        └── overlays/
            ├── test/         # Test cluster overlay
            └── prod/         # Prod cluster overlay
```

## Accessing ArgoCD UI

### Option 1: Port-forward (Default)

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Then access: <https://localhost:8080>

### Option 2: Ingress (Set `ingress_enabled = true`)

```hcl
ingress_enabled = true
ingress_host    = "argocd.yourdomain.com"
```

## Initial Setup

1. **Deploy ArgoCD:**

   ```bash
   cd infrastructure/dev/compute/argocd
   terragrunt apply
   ```

2. **Get admin password:**

   ```bash
   terragrunt output -raw argocd_initial_admin_password
   ```

3. **Access UI:**

   ```bash
   kubectl port-forward svc/argocd-server -n argocd 8080:443
   ```

   Login with username: `admin` and the password from step 2.

4. **Change admin password:**

   ```bash
   argocd login localhost:8080
   argocd account update-password
   ```

5. **Create Git repository structure:**

   ```bash
   mkdir -p kubernetes/argocd-apps
   mkdir -p kubernetes/apps/whoami/{base,overlays/test}
   ```

6. **Add your first application** (see example below)

## Example: Deploy whoami app

**ArgoCD Application** (`kubernetes/argocd-apps/whoami-test.yaml`):

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: whoami-test
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/username/homelab
    targetRevision: HEAD
    path: kubernetes/apps/whoami/overlays/test
  destination:
    server: https://kubernetes.default.svc
    namespace: whoami-test
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

**Kustomize base** (`kubernetes/apps/whoami/base/kustomization.yaml`):

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - service.yaml
```

**Test overlay** (`kubernetes/apps/whoami/overlays/test/kustomization.yaml`):

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

bases:
  - ../../base

namespace: whoami-test
```

Commit and push - ArgoCD will automatically deploy!

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| kubeconfig_path | Path to kubeconfig for hub cluster | `string` | n/a | yes |
| argocd_namespace | Namespace for ArgoCD | `string` | `"argocd"` | no |
| argocd_chart_version | ArgoCD Helm chart version | `string` | `"7.7.18"` | no |
| repo_url | Git repository URL | `string` | n/a | yes |
| repo_branch | Git branch to track | `string` | `"main"` | no |
| root_app_path | Path to Application manifests | `string` | `"kubernetes/argocd-apps"` | no |
| admin_password | Initial admin password | `string` | n/a | yes |
| ingress_enabled | Enable ingress | `bool` | `false` | no |
| ingress_host | Ingress hostname | `string` | `""` | no |
| spoke_clusters | Map of spoke clusters | `map(object)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| argocd_namespace | ArgoCD namespace |
| argocd_server_url | ArgoCD server URL |
| argocd_initial_admin_password | Initial admin password (sensitive) |
| root_app_status | Root Application status |
| registered_clusters | List of registered clusters |

## Adding Spoke Clusters

When you deploy new clusters (prod, shared-services), register them:

```hcl
spoke_clusters = {
  prod = {
    server      = "https://prod-api:6443"
    ca_data     = dependency.prod_cluster.outputs.cluster_ca_certificate
    cert_data   = dependency.prod_cluster.outputs.client_certificate
    key_data    = dependency.prod_cluster.outputs.client_key
    description = "Production cluster"
  }
  shared-services = {
    server      = "https://shared-api:6443"
    ca_data     = dependency.shared_cluster.outputs.cluster_ca_certificate
    cert_data   = dependency.shared_cluster.outputs.client_certificate
    key_data    = dependency.shared_cluster.outputs.client_key
    description = "Shared services cluster"
  }
}
```

## References

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [App of Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)
- [Kustomize](https://kustomize.io/)
