# Kubernetes GitOps — Flux

Kubernetes workloads for the `k8s-shared` Talos cluster, delivered by
[Flux](https://fluxcd.io) via the [Flux Operator](https://fluxoperator.dev).
The Flux install itself is deployed by Terragrunt
(`infrastructure/prod/compute/flux/`); everything below is reconciled from Git.

## Directory structure

```text
kubernetes/
└── apps/
    ├── _flux/                       # Root Flux Kustomization set (synced by the FluxInstance)
    │   ├── kustomization.yaml        # Lists the per-app Kustomizations to apply
    │   └── <app>.yaml                # One Flux Kustomization per app (path + dependsOn + prune/wait)
    └── <app>/overlays/<cluster>/     # Per-app overlay
        ├── kustomization.yaml        # configMapGenerator (<app>-values) + resources
        ├── helmrelease.yaml          # HelmRelease -> charts/<app> (or upstream via HelmRepository)
        ├── values.yaml               # Helm values (materialised into a ConfigMap)
        └── external-secret.yaml      # optional, when the chart doesn't template it
```

## How it works

1. The `FluxInstance` (`infrastructure/prod/compute/flux/`) syncs `kubernetes/apps/_flux/`
   from `main` and installs the Flux controllers.
2. The root Kustomization applies each per-app Flux `Kustomization` in `_flux/`.
3. Each app Kustomization applies its overlay: a `HelmRelease`, a values `ConfigMap`
   (generated from `values.yaml`), and any `ExternalSecret`.
4. `helm-controller` renders the chart (`charts/<app>` or an upstream chart via
   `HelmRepository`) with the ConfigMap values and reconciles a real Helm release.

## Conventions

- **Values** go into a ConfigMap (`configMapGenerator`, `disableNameSuffixHash: true`)
  referenced by `HelmRelease.valuesFrom` — Flux has no direct cross-source `ref: values`.
- **Namespace ownership**: if a chart templates its own `Namespace`, the overlay must NOT
  also declare `namespace.yaml` (double-ownership breaks Helm). Charts that don't template
  one keep `namespace.yaml` in the overlay.
- **`dependsOn`**: postgresql → cnpg-operator, immich → postgresql.
- **No `install.remediation`** on HelmReleases — a failed install must never uninstall
  (helm-controller uses server-side apply, stricter than ArgoCD).
- **Storage**: democratic-csi (NFS + iSCSI from TrueNAS); keep PV `reclaimPolicy: Retain`.

## Adding an app

1. Create the chart in `charts/<app>/` (or use an upstream chart via `HelmRepository`).
2. Add the overlay under `kubernetes/apps/<app>/overlays/<cluster>/` (helmrelease + values + kustomization).
3. Add `kubernetes/apps/_flux/<app>.yaml` (a Flux `Kustomization`) and list it in `_flux/kustomization.yaml`.
4. Validate: `helm template <app> charts/<app> -f overlays/<cluster>/values.yaml | kubectl apply --dry-run=server -f -`.
5. Commit + push to `main`.

## Operations (no `flux` CLI in the devshell — use kubectl)

```bash
export KUBECONFIG=../infrastructure/prod/compute/k8s-shared/configs/kubeconfig-shared

kubectl get kustomizations,helmreleases -A         # state of everything
kubectl -n flux-system annotate gitrepository/flux-system \
  reconcile.fluxcd.io/requestedAt="$(date -u +%FT%TZ)" --overwrite   # force sync
kubectl -n <ns> describe helmrelease <app>          # why an app is failing
```

## Resources

- [Flux Operator](https://fluxoperator.dev) · [Flux CD](https://fluxcd.io/flux/)
- [HelmRelease](https://fluxcd.io/flux/components/helm/helmreleases/) · [Kustomization](https://fluxcd.io/flux/components/kustomize/kustomizations/)
