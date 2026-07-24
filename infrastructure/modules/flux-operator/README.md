# Flux Operator Module

Installs the [flux-operator](https://fluxoperator.dev) (controlplaneio-fluxcd)
via its OCI Helm chart, then applies a single `FluxInstance` that installs,
configures, and upgrades the Flux distribution and bootstraps the fleet sync
from Git.

Deployed side-by-side with ArgoCD during the ArgoCD → Flux migration. The
operator manages nothing app-side until per-app Flux `Kustomization`s are added
under `spec.sync.path` (`kubernetes/apps/_flux`), one at a time, during cutover.

## What it creates

1. `flux-system` namespace.
2. `flux-operator` Helm release (OCI chart `oci://ghcr.io/controlplaneio-fluxcd/charts/flux-operator`).
3. `FluxInstance` (applied via `kubectl` — the CRD does not exist at plan time,
   so `kubernetes_manifest` cannot be used). Installs the pinned Flux version,
   the four core controllers, and the Git sync source (`GitRepository`
   `flux-system` + root `Kustomization`).

## Key variables

| Variable | Default | Notes |
| --- | --- | --- |
| `flux_version` | `2.9.x` | Pinned range — operator auto-upgrades patch/minor. Never `latest`. |
| `operator_chart_version` | `0.56.0` | flux-operator release. |
| `cluster_size` | `small` | Controller resource preset. |
| `multitenant` | `false` | Keep false while HelmReleases reference the `flux-system` GitRepository cross-namespace. |
| `repo_ref` | `refs/heads/main` | Set to the migration branch until cutover completes. |
| `sync_path` | `kubernetes/apps/_flux` | Root Flux Kustomization set. |

## Verify after apply

```bash
kubectl -n flux-system get fluxinstance,fluxreport
flux get sources git -A
flux get kustomizations -A   # only the root until apps are cut over
```
