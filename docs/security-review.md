# Security Review

Last reviewed: 2026-02-27

## Overall Assessment: Good

Strong foundations with a few areas to harden.

## Critical / High Findings

### 1. Tailscale ACL default allow-all grant

`infrastructure/prod/tailscale/acl/main.tf:14`

The first grant rule `{ src = ["*"], dst = ["*"], ip = ["*"] }` allows any Tailscale
device to connect to any other. This overrides the intent of subsequent restrictive
rules.

**Fix:** Remove the wildcard grant and explicitly define allowed connections.

### 2. TLS verification disabled on Proxmox & MikroTik providers

- `infrastructure/prod/provider.hcl:28` — `insecure = true`
- `infrastructure/prod/compute/k8s-shared/provider.hcl:49` — `insecure = true`
- `infrastructure/prod/mikrotik/provider.hcl:25` — `insecure = true`

API tokens/credentials are sent over HTTPS without certificate verification, enabling MITM on the local network.

**Fix:** Configure proper CA certs or use self-signed certs with explicit trust rather than disabling verification entirely.

### 3. No Kubernetes NetworkPolicies

Zero `NetworkPolicy` resources found across the cluster. All pods can communicate with all other pods (default allow-all).

**Fix:** Add per-namespace policies, at minimum isolating sensitive workloads (ArgoCD, PostgreSQL, OpenObserve).

### 4. Jellyfin runs as privileged

`charts/jellyfin/templates/deployment-jellyfin.yaml:36`

Full host access for GPU passthrough (`privileged: true`). Consider using specific
device access + capabilities instead of full privileged mode.

## Medium Findings

| Issue | Location |
| --- | --- |
| Pi-hole hardcoded `WEBPASSWORD: "changeme"` | `nix/rpi-pihole/pihole.nix:49` |
| ArgoCD default admin password `"changeme"` | `infrastructure/modules/argocd/` |
| Slskd hardcoded credentials (`slskd/slskd`) | `nix/arr-stack/arr.nix:496` |
| OpenObserve ingress has no auth middleware | `kubernetes/apps/openobserve/overlays/shared/ingress.yaml` |
| Navidrome uses `latest` image tag | `charts/navidrome/values.yaml:7` |

## What's Done Well

- **1Password integration** — credentials never stored in git, loaded via `op run` + `.op-env.tpl`
- **ExternalSecrets operator** — K8s secrets pulled from 1Password at runtime
- **Terraform sensitive vars** — all provider credentials marked `sensitive = true`
- **MikroTik firewall** — comprehensive stateful rules with default-deny, good VLAN segmentation
- **SSH hardened everywhere** — password auth disabled, key-only, max 3 auth tries
- **DNS security** — DNSSEC hardening, DNS-over-TLS to Mullvad, rebinding protection
- **Gitignore coverage** — kubeconfig, talosconfig, tfstate, .env all properly excluded
- **osxphotos-export** — excellent pod security (non-root, drop ALL caps, seccomp)

## Recommended Priority

1. **Tailscale ACL** — remove wildcard grant (quick win, high impact)
2. **NetworkPolicies** — start with critical namespaces (argocd, postgresql, openobserve)
3. **TLS verification** — set up proper CA trust for Proxmox/MikroTik
4. **Default passwords** — replace `changeme` values with 1Password-sourced secrets or `random_password`
5. **Jellyfin privilege** — explore replacing `privileged: true` with specific capabilities + device access
