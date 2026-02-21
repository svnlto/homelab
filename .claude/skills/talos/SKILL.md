---
name: talos
description: Full lifecycle management for Talos Linux Kubernetes clusters (shared, apps). Status checks, troubleshooting, upgrades, scaling, and Terragrunt deployments.
argument-hint: [command] [cluster]
disable-model-invocation: true
---

# Talos Cluster Management

You are managing Talos Linux Kubernetes clusters in a homelab environment running on Proxmox VE.

## Cluster Inventory

| Cluster | VLAN | Subnet      | VIP (API) | CP Nodes    | Workers     | Hosts       |
|---------|------|-------------|-----------|-------------|-------------|-------------|
| shared  | 30   | 10.0.1.0/24 | 10.0.1.10 | 3 (400-402) | 2 (410-411) | din + grogu |
| apps    | 31   | 10.0.2.0/24 | 10.0.2.10 | 3 (500-502) | 2 (510-511) | grogu only  |

Worker2 in the shared cluster (VMID 411, grogu) has Intel Arc A310 GPU passthrough.

## Config File Paths

- **Talosconfig shared**: `infrastructure/prod/compute/k8s-shared/configs/talosconfig-shared`
- **Kubeconfig shared**: `infrastructure/prod/compute/k8s-shared/configs/kubeconfig-shared`
- **Talosconfig apps**: `infrastructure/prod/compute/k8s-apps/configs/talosconfig-apps`
- **Kubeconfig apps**: `infrastructure/prod/compute/k8s-apps/configs/kubeconfig-apps`
- **Globals**: `infrastructure/globals.hcl` (versions, IPs, VLANs)
- **Talos module**: `infrastructure/modules/talos-cluster/`

## How to Use talosctl and kubectl

Always specify the config file explicitly:

```bash
# talosctl - always use --talosconfig
talosctl --talosconfig infrastructure/prod/compute/k8s-shared/configs/talosconfig-shared \
  --nodes <node-ip> <command>

# kubectl - always use --kubeconfig
kubectl --kubeconfig infrastructure/prod/compute/k8s-shared/configs/kubeconfig-shared \
  <command>
```

For the apps cluster, substitute `k8s-apps` and the apps config files.

## Commands Reference

When the user invokes `/talos`, parse `$ARGUMENTS` to determine the action.
The first argument is the command, the second (optional) is the cluster
name (default: `shared`).

### Status & Health

- `/talos status [cluster]` — Show cluster health, node status, etcd members, and Kubernetes component status

  ```bash
  talosctl --talosconfig <config> --nodes <vip> health
  talosctl --talosconfig <config> --nodes <vip> get members
  kubectl --kubeconfig <config> get nodes -o wide
  kubectl --kubeconfig <config> get pods -A --field-selector=status.phase!=Running
  ```

- `/talos nodes [cluster]` — List all nodes with versions, IPs, and roles

  ```bash
  talosctl --talosconfig <config> --nodes <vip> get members
  kubectl --kubeconfig <config> get nodes -o wide
  ```

- `/talos services [cluster] [node-ip]` — Show Talos services on a specific node

  ```bash
  talosctl --talosconfig <config> --nodes <node-ip> services
  ```

- `/talos dashboard [cluster]` — Show resource usage across nodes

  ```bash
  kubectl --kubeconfig <config> top nodes
  kubectl --kubeconfig <config> top pods -A --sort-by=memory
  ```

### Troubleshooting

- `/talos logs [cluster] [service]` — Get logs from a Talos service (etcd, kubelet, containerd, etc.)

  ```bash
  talosctl --talosconfig <config> --nodes <node-ip> logs <service>
  ```

- `/talos events [cluster]` — Show recent Kubernetes events

  ```bash
  kubectl --kubeconfig <config> get events -A --sort-by='.lastTimestamp' | tail -30
  ```

- `/talos etcd [cluster]` — Check etcd health and member list

  ```bash
  talosctl --talosconfig <config> --nodes <vip> etcd members
  talosctl --talosconfig <config> --nodes <vip> etcd status
  ```

- `/talos disks [cluster] [node-ip]` — Show disk information on a node

  ```bash
  talosctl --talosconfig <config> --nodes <node-ip> disks
  ```

- `/talos dmesg [cluster] [node-ip]` — Show kernel messages

  ```bash
  talosctl --talosconfig <config> --nodes <node-ip> dmesg
  ```

### Kubernetes Workloads

- `/talos pods [cluster] [namespace]` — List pods (optionally filtered by namespace)

  ```bash
  kubectl --kubeconfig <config> get pods -A  # or -n <namespace>
  ```

- `/talos deployments [cluster]` — List all deployments

  ```bash
  kubectl --kubeconfig <config> get deployments -A
  ```

- `/talos storage [cluster]` — Show PVCs, PVs, and storage classes

  ```bash
  kubectl --kubeconfig <config> get sc,pv,pvc -A
  ```

### Upgrades

- `/talos upgrade-check [cluster]` — Check current versions and available upgrades
  1. Read current Talos and Kubernetes versions from `globals.hcl`
  2. Run `talosctl --talosconfig <config> --nodes <vip> version` to confirm running versions
  3. Check the Talos GitHub releases for newer versions
  4. Check the factory.talos.dev schematic compatibility
  5. Report version comparison and upgrade path

- `/talos upgrade [cluster]` — Plan a Talos upgrade (DO NOT execute without confirmation)
  1. Show current vs target versions
  2. Explain the upgrade order: control plane nodes first (one at a time), then workers
  3. Show the commands that would be run:

     ```bash
     talosctl --talosconfig <config> --nodes <cp-ip> upgrade \
       --image factory.talos.dev/installer/<schematic>:<version>
     ```

  4. Remind to update `globals.hcl` with new version/schematic after upgrade
  5. **ALWAYS ask for explicit confirmation before running any upgrade command**

### Infrastructure (Terragrunt)

- `/talos plan [cluster]` — Run Terragrunt plan for the cluster

  ```bash
  just tg-plan-module prod/compute/k8s-<cluster>
  ```

- `/talos apply [cluster]` — Run Terragrunt apply (requires confirmation)

  ```bash
  just tg-apply-module prod/compute/k8s-<cluster>
  ```

  **ALWAYS ask for explicit confirmation before applying.**

- `/talos config [cluster]` — Show the Terragrunt/Terraform configuration for a cluster
  Read and summarize the relevant files:
  - `infrastructure/prod/compute/k8s-<cluster>/terragrunt.hcl`
  - `infrastructure/prod/compute/k8s-<cluster>/main.tf`
  - `infrastructure/modules/talos-cluster/variables.tf`

### Cluster Configuration

- `/talos machine-config [cluster] [node-ip]` — Show the machine configuration for a node

  ```bash
  talosctl --talosconfig <config> --nodes <node-ip> get machineconfig -o yaml
  ```

- `/talos kubeconfig [cluster]` — Regenerate kubeconfig

  ```bash
  talosctl --talosconfig <config> --nodes <vip> kubeconfig <output-path>
  ```

### Bootstrap Components

- `/talos bootstrap-status [cluster]` — Check status of bootstrap components

  ```bash
  # Cilium
  kubectl --kubeconfig <config> -n kube-system get pods -l app.kubernetes.io/name=cilium

  # MetalLB
  kubectl --kubeconfig <config> -n metallb-system get pods

  # Traefik
  kubectl --kubeconfig <config> -n traefik get pods

  # Democratic-CSI (NFS + iSCSI)
  kubectl --kubeconfig <config> -n democratic-csi get pods

  # Tailscale (if enabled)
  kubectl --kubeconfig <config> -n tailscale get pods
  ```

## Argument Parsing Rules

1. If no arguments: show help summary of available commands
2. If only a command: default to the `shared` cluster
3. Cluster argument can be `shared`, `apps`, or `all` (run against both clusters)
4. Node IPs can be passed for node-specific commands; if omitted, use VIP

## Safety Rules

- **NEVER run `talosctl upgrade`, `talosctl reset`, or `terragrunt apply` without explicit user confirmation**
- **NEVER run destructive etcd operations** (remove-member, snapshot restore) without confirmation
- For upgrade operations, always explain the plan first and wait for approval
- When running commands against `all` clusters, run them sequentially (shared first, then apps)

## Current Versions (from globals.hcl)

Read `infrastructure/globals.hcl` for the current `talos_version`,
`kubernetes_version`, and `schematic_id` before any version-related
operations.
