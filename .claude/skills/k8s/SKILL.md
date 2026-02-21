---
name: k8s
description: Kubernetes workload management for homelab clusters. ArgoCD apps, deployments, pods, logs, storage, networking, and debugging.
argument-hint: [command] [cluster]
disable-model-invocation: true
---

# Kubernetes Workload Management

You are managing Kubernetes workloads on Talos Linux clusters in a homelab
environment. Workloads are deployed via ArgoCD (app-of-apps pattern) on
the shared cluster.

## Clusters

| Cluster | VIP       | Kubeconfig Path                                                    |
|---------|-----------|--------------------------------------------------------------------|
| shared  | 10.0.1.10 | `infrastructure/prod/compute/k8s-shared/configs/kubeconfig-shared` |
| apps    | 10.0.2.10 | `infrastructure/prod/compute/k8s-apps/configs/kubeconfig-apps`     |

Default cluster is `shared` when not specified.

Always use `kubectl --kubeconfig <path>` explicitly.

## ArgoCD Setup

- **Namespace**: `argocd`
- **Cluster**: shared (hub cluster)
- **Git repo**: `https://github.com/svnlto/homelab` (branch: `main`)
- **Root app path**: `kubernetes/argocd-apps/` (directory recurse, auto-sync with prune + selfHeal)
- **App definitions**: `kubernetes/argocd-apps/*.yaml` (one per app)
- **App manifests**: `kubernetes/apps/<app-name>/` (Kustomize: base + overlays/shared)

### Deployed Apps

| App              | Namespace      | Description                                |
|------------------|----------------|--------------------------------------------|
| arr-stack        | arr-stack      | Sonarr, Radarr, Prowlarr, Lidarr, SABnzbd  |
| jellyfin         | jellyfin       | Jellyfin media server + Jellyseerr         |
| navidrome        | navidrome      | Music streaming server                     |
| dumper           | dumper         | Backup/dump utility                        |
| metrics-server   | kube-system    | Kubernetes metrics server (Helm)           |
| signoz           | signoz         | SigNoz observability platform (Helm)       |
| signoz-k8s-infra | signoz         | SigNoz K8s infrastructure collector (Helm) |
| infrastructure   | infrastructure | TrueNAS NFS PV/PVC definitions             |

## Commands Reference

When the user invokes `/k8s`, parse `$ARGUMENTS` to determine the action.
First argument is the command, second (optional) is the cluster name
(default: `shared`).

### ArgoCD

- `/k8s apps [cluster]` — List all ArgoCD applications and their sync status

  ```bash
  kubectl --kubeconfig <config> -n argocd get applications
  ```

- `/k8s app <app-name> [cluster]` — Show detailed status of a specific ArgoCD application

  ```bash
  kubectl --kubeconfig <config> -n argocd get application <app-name> -o yaml
  ```

- `/k8s sync <app-name> [cluster]` — Trigger an ArgoCD sync for an app
  **Ask for confirmation before syncing.**

  ```bash
  kubectl --kubeconfig <config> -n argocd patch application <app-name> \
    --type merge -p '{"operation":{"sync":{"revision":"HEAD"}}}'
  ```

- `/k8s diff <app-name>` — Show what would change on next sync
  Read the ArgoCD app spec and compare with the manifests in `kubernetes/apps/<app-name>/`.

### Workloads

- `/k8s pods [cluster] [namespace]` — List pods, optionally filtered by namespace

  ```bash
  kubectl --kubeconfig <config> get pods -A  # or -n <namespace>
  ```

- `/k8s deployments [cluster] [namespace]` — List deployments

  ```bash
  kubectl --kubeconfig <config> get deployments -A
  ```

- `/k8s services [cluster] [namespace]` — List services with IPs

  ```bash
  kubectl --kubeconfig <config> get svc -A
  ```

- `/k8s logs <pod-name> [cluster] [namespace] [container]` — Get pod logs

  ```bash
  kubectl --kubeconfig <config> -n <namespace> logs <pod-name> [-c <container>] --tail=100
  ```

- `/k8s describe <resource-type> <name> [cluster] [namespace]` — Describe a resource

  ```bash
  kubectl --kubeconfig <config> [-n <namespace>] describe <resource-type> <name>
  ```

- `/k8s events [cluster] [namespace]` — Show recent events

  ```bash
  kubectl --kubeconfig <config> get events [-n <namespace> | -A] --sort-by='.lastTimestamp' | tail -30
  ```

- `/k8s restart <deployment-name> [cluster] [namespace]` — Rolling restart a deployment
  **Ask for confirmation before restarting.**

  ```bash
  kubectl --kubeconfig <config> -n <namespace> rollout restart deployment/<deployment-name>
  ```

### Storage

- `/k8s storage [cluster]` — Show storage classes, PVs, and PVCs

  ```bash
  kubectl --kubeconfig <config> get sc
  kubectl --kubeconfig <config> get pv
  kubectl --kubeconfig <config> get pvc -A
  ```

- `/k8s pvc [cluster] [namespace]` — List PVCs with capacity and status

  ```bash
  kubectl --kubeconfig <config> get pvc -A -o wide
  ```

### Networking

- `/k8s ingress [cluster]` — List all ingress resources and their hosts

  ```bash
  kubectl --kubeconfig <config> get ingress -A
  ```

- `/k8s endpoints [cluster] [namespace]` — List service endpoints

  ```bash
  kubectl --kubeconfig <config> get endpoints -A
  ```

- `/k8s metallb [cluster]` — Show MetalLB IP assignments

  ```bash
  kubectl --kubeconfig <config> -n metallb-system get ipaddresspool,l2advertisement
  kubectl --kubeconfig <config> get svc -A --field-selector spec.type=LoadBalancer
  ```

### Debugging

- `/k8s top [cluster]` — Show resource usage (nodes and top pods)

  ```bash
  kubectl --kubeconfig <config> top nodes
  kubectl --kubeconfig <config> top pods -A --sort-by=memory | head -20
  ```

- `/k8s failed [cluster]` — Show pods not in Running/Succeeded state

  ```bash
  kubectl --kubeconfig <config> get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded
  ```

- `/k8s exec <pod-name> [cluster] [namespace] -- <command>` — Execute a command in a pod
  **Ask for confirmation before executing.**

  ```bash
  kubectl --kubeconfig <config> -n <namespace> exec -it <pod-name> -- <command>
  ```

### Manifests

- `/k8s show <app-name>` — Read and display the Kubernetes manifests for an app
  Read files from `kubernetes/apps/<app-name>/` and `kubernetes/argocd-apps/<app-name>.yaml`.

- `/k8s edit <app-name>` — Edit manifests for an ArgoCD app
  Open files in `kubernetes/apps/<app-name>/` for editing. After edits, remind the user to commit and push for ArgoCD auto-sync.

### Helm

- `/k8s helm [cluster]` — List Helm releases

  ```bash
  kubectl --kubeconfig <config> get secrets -A -l owner=helm --field-selector type=helm.sh/release.v1 \
    -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.labels.name}{"\t"}{.metadata.labels.version}{"\n"}{end}'
  ```

## Argument Parsing Rules

1. If no arguments: show help summary of available commands
2. If only a command: default to the `shared` cluster
3. Cluster can be `shared`, `apps`, or `all`
4. Namespace defaults to all (`-A`) unless specified

## Safety Rules

- **NEVER delete pods, deployments, or namespaces without explicit user confirmation**
- **NEVER run `kubectl delete` or `kubectl apply` without confirmation**
- For ArgoCD syncs, explain what will happen before proceeding
- When editing manifests, remind the user that ArgoCD will auto-sync on push
