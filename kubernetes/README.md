# Kubernetes GitOps - ArgoCD Hub-and-Spoke

This directory contains Kubernetes manifests managed by ArgoCD using the hub-and-spoke architecture with Kustomize overlays.

## Directory Structure

```
kubernetes/
├── argocd-apps/              # ArgoCD Application definitions (watched by root app)
│   └── whoami-test.yaml      # Deploy whoami to test cluster
├── apps/                     # Kustomize application manifests
│   └── whoami/
│       ├── base/             # Common manifests (all clusters)
│       │   ├── deployment.yaml
│       │   ├── service.yaml
│       │   └── kustomization.yaml
│       └── overlays/         # Cluster-specific customizations
│           └── test/         # Test cluster overlay
│               └── kustomization.yaml
└── README.md                 # This file
```

## How It Works

### 1. ArgoCD Root App (App of Apps)

ArgoCD's root Application watches `kubernetes/argocd-apps/` directory. Any Application manifests added here are automatically deployed.

### 2. Application Definitions

Each file in `argocd-apps/` defines:

- **Source**: Where to find manifests (Git repo + path)
- **Destination**: Which cluster + namespace to deploy to
- **Sync Policy**: How to keep cluster in sync with Git

### 3. Kustomize Overlays

Applications use Kustomize to share common manifests while customizing per cluster:

- `base/` - Common manifests shared by all clusters
- `overlays/<cluster>/` - Cluster-specific customizations (replicas, ingress, etc.)

## GitOps Workflow

```
┌─────────────────────────────────────────────────────┐
│ 1. Developer: git commit + push                    │
│    - Add/modify manifests in kubernetes/apps/      │
│    - Add/modify Application in argocd-apps/        │
└──────────────────┬──────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────┐
│ 2. ArgoCD: Detects Git changes (every 3 min)       │
│    - Root app watches argocd-apps/                 │
└──────────────────┬──────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────┐
│ 3. ArgoCD: Syncs Application                       │
│    - Runs: kustomize build apps/whoami/overlays/test│
│    - Applies generated YAML to cluster              │
└──────────────────┬──────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────┐
│ 4. Kubernetes: Deploys/Updates resources           │
│    - Creates/updates Deployment, Service, etc.     │
└─────────────────────────────────────────────────────┘
```

## Example: Deploy whoami App

### Current Setup

**whoami-test** is deployed to the test cluster (hub).

**To verify:**

```bash
# Check ArgoCD Application status
kubectl --kubeconfig ../infrastructure/dev/compute/test-cluster/configs/kubeconfig-test \
  get application -n argocd whoami-test

# Check deployed resources
kubectl --kubeconfig ../infrastructure/dev/compute/test-cluster/configs/kubeconfig-test \
  get all -n whoami-test

# Test the app
kubectl --kubeconfig ../infrastructure/dev/compute/test-cluster/configs/kubeconfig-test \
  port-forward -n whoami-test svc/whoami 8081:80

# Then: curl http://localhost:8081
```

## Adding a New Application

### Step 1: Create Base Manifests

```bash
mkdir -p kubernetes/apps/myapp/base
cd kubernetes/apps/myapp/base
```

Create:

- `deployment.yaml`
- `service.yaml`
- `kustomization.yaml`

### Step 2: Create Overlay

```bash
mkdir -p kubernetes/apps/myapp/overlays/test
cd kubernetes/apps/myapp/overlays/test
```

Create `kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

bases:
  - ../../base

namespace: myapp-test

commonLabels:
  environment: test
```

### Step 3: Create ArgoCD Application

```bash
cat > kubernetes/argocd-apps/myapp-test.yaml <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp-test
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/svnlto/homelab
    targetRevision: HEAD
    path: kubernetes/apps/myapp/overlays/test
  destination:
    server: https://kubernetes.default.svc
    namespace: myapp-test
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF
```

### Step 4: Commit and Push

```bash
git add kubernetes/
git commit -m "Add myapp to test cluster"
git push
```

ArgoCD will automatically detect and deploy within 3 minutes!

## Multi-Cluster Deployment

### Deploy to Multiple Clusters

To deploy the same app to different clusters, create multiple Application manifests:

**Test cluster** (`argocd-apps/myapp-test.yaml`):

```yaml
destination:
  server: https://kubernetes.default.svc  # Hub (test) cluster
  namespace: myapp-test
source:
  path: kubernetes/apps/myapp/overlays/test
```

**Prod cluster** (`argocd-apps/myapp-prod.yaml`):

```yaml
destination:
  name: prod  # Spoke cluster (registered with ArgoCD)
  namespace: myapp-prod
source:
  path: kubernetes/apps/myapp/overlays/prod
```

### Register Spoke Clusters

Update `infrastructure/dev/compute/argocd/terragrunt.hcl`:

```hcl
spoke_clusters = {
  prod = {
    server      = "https://prod-api:6443"
    ca_data     = dependency.prod_cluster.outputs.cluster_ca_certificate
    cert_data   = dependency.prod_cluster.outputs.client_certificate
    key_data    = dependency.prod_cluster.outputs.client_key
    description = "Production cluster"
  }
}
```

Run `terragrunt apply` to register the cluster.

## Kustomize Tips

### Common Patterns

**1. Different replicas per cluster:**

```yaml
# overlays/test/kustomization.yaml
patches:
  - target:
      kind: Deployment
      name: myapp
    patch: |-
      - op: replace
        path: /spec/replicas
        value: 1  # Test: 1 replica
```

**2. Different resource limits:**

```yaml
patches:
  - target:
      kind: Deployment
      name: myapp
    patch: |-
      - op: replace
        path: /spec/template/spec/containers/0/resources/limits/memory
        value: 256Mi  # Test: smaller limits
```

**3. Cluster-specific ConfigMap:**

```yaml
# overlays/test/config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: myapp-config
data:
  environment: test
  debug: "true"
```

```yaml
# overlays/test/kustomization.yaml
resources:
  - config.yaml  # Add to resources
```

## Troubleshooting

### ArgoCD not syncing

```bash
# Check Application status
kubectl get application -n argocd whoami-test -o yaml

# Force sync
kubectl patch application whoami-test -n argocd \
  --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'
```

### Kustomize build errors

```bash
# Test Kustomize locally
cd kubernetes/apps/whoami/overlays/test
kustomize build .
```

### View generated manifests

```bash
# See what ArgoCD will deploy
kubectl --kubeconfig ../infrastructure/dev/compute/test-cluster/configs/kubeconfig-test \
  get application whoami-test -n argocd -o jsonpath='{.status.sync.comparedTo.source}' | jq
```

## Resources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Kustomize Documentation](https://kustomize.io/)
- [App of Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)
