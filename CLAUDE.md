# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Raspberry Pi 4 Kubernetes homelab using a **hybrid two-stage deployment approach**:

1. **Packer**: Builds immutable base OS image with Kubernetes binaries pre-installed
2. **Ansible**: Orchestrates cluster initialization and node joining

This separation allows fast rebuilds for OS/K8s version updates while keeping cluster orchestration flexible.

## Hardware Specifications

- **Raspberry Pi 4 Model B**
- **RAM**: 8GB per node
- **Storage**: 128GB per node (SD card or SSD recommended)

## Technology Stack

- **OS**: Ubuntu 24.04 LTS ARM64
- **Kubernetes**: v1.34 (full kubeadm, not k3s)
- **Container Runtime**: containerd
- **CNI**: Flannel v0.25.7
- **LoadBalancer**: MetalLB v0.14.9 (Layer 2)
- **Ingress**: Traefik v3
- **Storage**: Longhorn v1.7.2
- **Certificates**: cert-manager v1.16.2
- **Development**: Nix flakes for reproducible tooling

## Essential Commands

### Development Environment

```bash
# Enter Nix development shell (loads all tools)
nix develop

# Or use direnv for automatic activation
direnv allow

# Install pre-commit hooks
just setup
```

### Image Building

**IMPORTANT**: ARM image building on macOS requires Vagrant + QEMU because macOS
Docker Desktop cannot mount loop devices. The Vagrantfile creates an x86_64
Ubuntu VM that runs the `mkaczanowski/packer-builder-arm` Docker container with privileged access.

```bash
# Start Vagrant VM (first time ~5 min)
just vagrant-up

# Build Packer image inside VM (30-60 minutes)
just packer-build

# Output: packer/output-rpi-k8s/rpi-k8s-base.img
```

The build runs this Docker command inside Vagrant:

```bash
docker run --rm --privileged \
  -v /dev:/dev \
  -v $(pwd):/build \
  mkaczanowski/packer-builder-arm:latest \
  build /build/rpi-k8s-base.pkr.hcl
```

### Cluster Deployment

```bash
# Test Ansible connectivity
just test-ansible

# Deploy cluster (5-10 minutes)
just ansible-deploy

# Full deployment from scratch
just deploy-full

# Get kubeconfig from control plane
just k8s-get-config
export KUBECONFIG=~/.kube/homelab-config
```

### Kubernetes Components

```bash
# Install all components in order
just k8s-install-all

# Or install individually
just k8s-install-metallb      # LoadBalancer (required first)
just k8s-install-longhorn     # Storage
just k8s-install-certmanager  # Certificates
just k8s-install-traefik      # Ingress

# Check cluster status
just k8s-status
just k9s
```

### Linting and Testing

```bash
# Run all pre-commit hooks manually
pre-commit run --all-files

# Test Ansible syntax
just test-syntax

# Test Ansible connectivity
just test-ansible
```

## Architecture

### Two-Stage Deployment Pipeline

```text
┌─────────────────────────────────────────────────────────────┐
│ Stage 1: Packer (Image Building)                            │
│ ─────────────────────────────────────────────────────────── │
│ 1. Download Ubuntu 24.04 ARM64 image                        │
│ 2. Mount and chroot into image                              │
│ 3. Run inline provisioning (defined in rpi-k8s-base.pkr.hcl):│
│    - System setup: kernel params, cgroups, swap off         │
│    - Container runtime: install containerd                  │
│    - Kubernetes: install kubeadm, kubelet, kubectl          │
│ 4. Output: rpi-k8s-base.img (8GB image)                     │
└─────────────────────────────────────────────────────────────┘
                           ↓
                    Flash to SD cards
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ Stage 2: Ansible (Cluster Orchestration)                    │
│ ─────────────────────────────────────────────────────────── │
│ Playbook execution order (site.yml):                        │
│                                                              │
│ 1. common role (all nodes):                                 │
│    - Set hostnames and /etc/hosts                           │
│    - Load kernel modules (br_netfilter, overlay)            │
│    - Enable kubelet service                                 │
│                                                              │
│ 2. control-plane role:                                      │
│    - Run: kubeadm init --pod-network-cidr=10.244.0.0/16     │
│    - Install Flannel CNI                                    │
│    - Generate worker join token                             │
│    - Save join command to /tmp/kubeadm_join_command.sh      │
│                                                              │
│ 3. worker role (runs on all workers):                       │
│    - Copy join command from control plane                   │
│    - Run: kubeadm join <control-plane-ip>:6443 --token ...  │
│    - Label nodes as workers                                 │
└─────────────────────────────────────────────────────────────┘
```

### Why This Approach?

- **Packer**: Ensures all nodes have identical base configuration, faster than provisioning from scratch
- **Ansible**: Handles cluster-specific orchestration (token generation, join commands) that can't be baked into an image
- **Separation**: Update OS/K8s versions via image rebuild, change cluster config via Ansible

### Key Configuration Variables

Located in `ansible/group_vars/`:

- `all.yml`: Global settings (pod CIDR, service CIDR, MetalLB range)
- `control_plane.yml`: Control plane specific settings

Network configuration:

- Pod network: `10.244.0.0/16` (Flannel default)
- Service CIDR: `10.96.0.0/12` (Kubernetes default)
- MetalLB pool: `192.168.1.200-192.168.1.220` (customize for your network)

### Ansible Idempotency

All roles check for existing state before making changes:

- `control-plane`: Checks `/etc/kubernetes/admin.conf` exists before running `kubeadm init`
- `worker`: Checks `/etc/kubernetes/kubelet.conf` exists before joining
- Common: Checks if node already in cluster

This allows safe re-runs of `just ansible-deploy`.

## File Structure

```text
homelab/
├── flake.nix                    # Nix dev environment (defines all tools)
├── justfile                     # Command runner (all automation)
├── Vagrantfile                  # Ubuntu VM for ARM image building
├── .pre-commit-config.yaml      # Quality checks (ansible-lint, yamlfmt, markdownlint)
│
├── packer/
│   ├── rpi-k8s-base.pkr.hcl    # Main Packer config with inline provisioners
│   └── output-rpi-k8s/         # Build output directory
│
├── ansible/
│   ├── ansible.cfg             # Ansible configuration
│   ├── inventory.yml           # Node IPs and hostnames (UPDATE THIS)
│   ├── site.yml                # Main playbook (orchestrates roles)
│   ├── group_vars/
│   │   ├── all.yml            # Global vars (CIDR, versions, MetalLB)
│   │   └── control_plane.yml  # Control plane specific vars
│   └── roles/
│       ├── common/tasks/main.yml          # Setup all nodes
│       ├── control-plane/tasks/main.yml   # Initialize cluster
│       └── worker/tasks/main.yml          # Join workers
│
└── kubernetes/manifests/
    ├── metallb-config.yaml     # IP pool configuration
    ├── traefik-values.yaml     # Traefik Helm values
    ├── cert-manager.yaml       # Certificate issuers
    └── longhorn-values.yaml    # Longhorn Helm values
```

## Configuration Required Before Deployment

### 1. Static IPs (Manual Step)

After flashing SD cards, boot each Pi and configure static IPs via netplan:

```bash
ssh ubuntu@<dhcp-ip>
sudo nano /etc/netplan/50-cloud-init.yaml
```

Recommended IPs:

- Control plane: `192.168.1.101`
- Worker 1: `192.168.1.102`
- Worker 2: `192.168.1.103`
- Worker 3: `192.168.1.104`

### 2. Update Ansible Inventory

Edit `ansible/inventory.yml` with your actual IPs:

```yaml
control_plane:
  hosts:
    rpi-control-01:
      ansible_host: 192.168.1.101  # <- Your IP
      node_ip: 192.168.1.101
```

### 3. Update MetalLB Range

Edit `ansible/group_vars/all.yml`:

```yaml
metallb_ip_range: "192.168.1.200-192.168.1.220"  # Adjust for your network
```

Also update `kubernetes/manifests/metallb-config.yaml` to match.

## Common Workflows

### Updating Kubernetes Version

```bash
# 1. Update version in packer/rpi-k8s-base.pkr.hcl
# variable "k8s_version" { default = "1.35" }

# 2. Update checksum (download new Ubuntu image and get sha256)

# 3. Rebuild image
just packer-build

# 4. Flash new image to SD cards

# 5. Reconfigure static IPs (netplan)

# 6. Redeploy cluster
just ansible-deploy
```

### Adding a Worker Node

```bash
# 1. Flash SD card with base image
# 2. Configure static IP via netplan
# 3. Add to ansible/inventory.yml under workers:
# 4. Run deployment limited to new node
cd ansible
ansible-playbook -i inventory.yml site.yml --limit new-worker-hostname
```

### Troubleshooting Failed Node Join

```bash
# On control plane, regenerate join token
ssh ubuntu@192.168.1.101
sudo kubeadm token create --print-join-command

# On worker, reset and rejoin
ssh ubuntu@192.168.1.102
sudo kubeadm reset -f
sudo <paste-join-command>
```

### Backup etcd

```bash
just backup-etcd
# Saves to: etcd-backup-YYYYMMDD-HHMMSS.db
```

## Testing

```bash
# Deploy test nginx with LoadBalancer
just test-deploy
kubectl get svc nginx-test  # Get external IP
curl http://<EXTERNAL-IP>

# Cleanup
just test-cleanup
```

## Important Notes

### Packer Build Requirements

- **macOS**: Must use Vagrant + QEMU (loop device limitation)
- **Linux**: Can run Packer directly with `--privileged` Docker
- **Build time**: 30-60 minutes depending on network and CPU
- **Provisioning**: Uses inline shell commands (not external scripts) to avoid chroot upload issues with packer-builder-arm
- **Cache**: Automatically cleaned before each build to prevent corrupt download issues

### ARM64 Image Availability

Not all container images support ARM64. Before deploying applications:

```bash
docker manifest inspect <image:tag> | grep arm64
```

### Storage Considerations

**Hardware**: 128GB storage per node (SD card or SSD)

- Use A2-rated SD cards for better IOPS
- Limited write cycles on SD cards: expect quarterly replacement
- **Recommended**: Use USB3 SSDs instead of SD cards for better performance and longevity
- Longhorn benefits significantly from SSD storage

### Resource Limits

**Hardware**: 8GB RAM per Raspberry Pi 4 node

- Set resource requests/limits on pods to prevent memory exhaustion
- Monitor resource usage: `kubectl top nodes` and `just k9s`
- Consider pod priority classes for critical workloads

## Version Information

See `VERSIONS.md` for detailed compatibility matrix and upgrade paths.

Current stable versions:

- Kubernetes: v1.34
- Ubuntu: 24.04.1 LTS
- Flannel: v0.25.7
- MetalLB: v0.14.9
- Longhorn: v1.7.2
- Traefik: v3.x
- cert-manager: v1.16.2
