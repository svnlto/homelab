# Raspberry Pi 4 Kubernetes Homelab

Production-ready 4-node Kubernetes cluster on Raspberry Pi 4 using Nix, Packer, and Ansible.

## Stack

- **OS**: Ubuntu 24.04 LTS ARM64
- **Kubernetes**: v1.34 (kubeadm)
- **Container Runtime**: containerd
- **CNI**: Flannel
- **LoadBalancer**: MetalLB v0.14.9
- **Ingress**: Traefik v3
- **Storage**: Longhorn v1.7.2
- **Certificates**: cert-manager v1.16.2

## Hardware

- **4x Raspberry Pi 4 Model B**
  - **RAM**: 8GB per node
  - **Storage**: 128GB per node (SD card or USB3 SSD)
- **Network**: Gigabit switch and Ethernet cables

## Architecture

- **1x Control Plane**: Coordinates cluster operations
- **3x Workers**: Run application workloads
- **Hybrid Approach**: Packer builds base image, Ansible orchestrates cluster

## Prerequisites

- macOS with Nix installed
- 4x Raspberry Pi 4 (8GB RAM, 128GB storage each)
- Network switch and Ethernet cables
- SSH access configured

## Quick Start

### 1. Setup Development Environment

```bash
# Install Nix (if needed)
sh <(curl -L https://nixos.org/nix/install)

# Configure Nix flakes
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf

# Enter development environment
cd ~/Projects/homelab
nix develop
# or use direnv: direnv allow

# Install pre-commit hooks (optional)
brew install pre-commit
just setup
```

### 2. Build Base Image (30-60 minutes)

**Note**: Building ARM images on macOS requires Vagrant + QEMU due to loop device limitations in Docker Desktop.

```bash
# Install vagrant-qemu plugin (first time only)
vagrant plugin install vagrant-qemu

# Start the Vagrant VM (first time takes ~5 minutes)
just vagrant-up

# Build the image inside the VM (30-60 minutes)
just packer-build
```

**Output**: `packer/output-rpi-k8s/rpi-k8s-base.img`

**What's included in the image**:

- Ubuntu 24.04 LTS ARM64
- containerd runtime
- kubeadm, kubelet, kubectl (v1.34)
- Optimized kernel parameters and cgroup settings

### 3. Flash SD Cards

Use Raspberry Pi Imager:

1. Open Raspberry Pi Imager
2. Choose "Use custom" image
3. Select `packer/output-rpi-k8s/rpi-k8s-base.img`
4. Flash to all 4 SD cards

Or use `dd`:

```bash
diskutil list
diskutil unmountDisk /dev/diskN
sudo dd if=packer/output-rpi-k8s/rpi-k8s-base.img of=/dev/rdiskN bs=4m status=progress
diskutil eject /dev/diskN
```

### 4. Configure Static IPs

Boot all Pis and SSH into each:

```bash
# Default credentials: ubuntu/ubuntu (you'll be prompted to change)
ssh ubuntu@<pi-ip>

# Edit netplan
sudo nano /etc/netplan/50-cloud-init.yaml
```

Example configuration:

```yaml
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: no
      addresses:
        - 192.168.1.101/24  # Change for each node
      routes:
        - to: default
          via: 192.168.1.1
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
```

```bash
sudo netplan apply
```

**Recommended IPs**:

- Control plane: 192.168.1.101
- Worker 1: 192.168.1.102
- Worker 2: 192.168.1.103
- Worker 3: 192.168.1.104

### 5. Configure Ansible

Update `ansible/inventory.yml` with your IPs:

```yaml
control_plane:
  hosts:
    rpi-control-01:
      ansible_host: 192.168.1.101
      node_ip: 192.168.1.101
      node_name: rpi-control-01

workers:
  hosts:
    rpi-worker-01:
      ansible_host: 192.168.1.102
      node_ip: 192.168.1.102
      node_name: rpi-worker-01
    # ... etc
```

Update MetalLB IP range in `ansible/group_vars/all.yml`:

```yaml
metallb_ip_range: "192.168.1.200-192.168.1.220"
```

Copy SSH keys:

```bash
ssh-copy-id ubuntu@192.168.1.101  # Repeat for all nodes
just test-ansible  # Test connectivity
```

### 6. Deploy Kubernetes Cluster

```bash
just ansible-deploy  # Deploy cluster (5-10 minutes)

# Get kubeconfig
just k8s-get-config

# Verify cluster
export KUBECONFIG=~/.kube/homelab-config
kubectl get nodes
```

### 7. Install Cluster Components

```bash
# Install all components in order (15-20 minutes)
just k8s-install-all

# Or install individually:
just k8s-install-metallb      # LoadBalancer
just k8s-install-longhorn     # Storage
just k8s-install-certmanager  # Certificates
just k8s-install-traefik      # Ingress

# Get Traefik LoadBalancer IP
kubectl get svc -n traefik traefik

# Add to /etc/hosts
sudo bash -c 'echo "192.168.1.200 traefik.local longhorn.local" >> /etc/hosts'
```

### 8. Access Dashboards

- **Traefik**: <https://traefik.local>
- **Longhorn**: <http://longhorn.local>
- **k9s**: Run `k9s` in terminal

## Just Commands

```bash
just --list              # Show all commands

# Image building
just packer-build        # Build Packer image
just rebuild             # Rebuild and prepare for reflash

# Cluster deployment
just ansible-check       # Dry-run deployment
just ansible-deploy      # Deploy cluster
just deploy-full         # Full deployment from scratch

# Kubernetes management
just k8s-status          # Show cluster status
just k8s-get-config      # Fetch kubeconfig
just k8s-install-all     # Install all components
just k8s-watch           # Watch pods
just k9s                 # Launch k9s TUI

# Utilities
just test-ansible        # Test connectivity
just ssh NODE            # SSH to node
just backup-etcd         # Backup etcd
just versions            # Show versions
just clean               # Clean artifacts

# Development
just setup               # Install pre-commit hooks
just lint                # Run all linters
```

## Configuration Files

Before deployment, update these files:

1. `ansible/inventory.yml` - Node IP addresses
2. `ansible/group_vars/all.yml` - Network ranges (MetalLB)
3. `kubernetes/manifests/metallb-config.yaml` - IP pool
4. `kubernetes/manifests/cert-manager.yaml` - Email for Let's Encrypt
5. `kubernetes/manifests/traefik-values.yaml` - Email and domain

## Directory Structure

```text
homelab/
├── flake.nix                           # Nix development environment
├── justfile                            # Command runner
├── packer/
│   ├── rpi-k8s-base.pkr.hcl           # Packer config
│   ├── variables.pkr.hcl              # Packer variables
│   └── scripts/                       # Provisioning scripts
│       ├── 01-system-setup.sh
│       ├── 02-container-runtime.sh
│       └── 03-kubernetes.sh
├── ansible/
│   ├── ansible.cfg
│   ├── inventory.yml                  # Node inventory
│   ├── site.yml                       # Main playbook
│   ├── group_vars/
│   │   ├── all.yml                    # Global variables
│   │   └── control_plane.yml          # Control plane vars
│   └── roles/
│       ├── common/tasks/main.yml
│       ├── control-plane/tasks/main.yml
│       └── worker/tasks/main.yml
└── kubernetes/
    ├── manifests/
    │   ├── metallb-config.yaml
    │   ├── traefik-values.yaml
    │   ├── cert-manager.yaml
    │   └── longhorn-values.yaml
    └── apps/                          # Your applications
```

## Deployment Timeline

- Packer build: 30-60 minutes (one-time)
- SD card flashing: 60 minutes (15 min × 4)
- Static IP setup: 20 minutes
- Ansible deployment: 5-10 minutes
- Components install: 15-20 minutes
- **Total: 1-2 hours**

## Testing

```bash
# Deploy test nginx app
just test-deploy
kubectl get svc nginx-test  # Get LoadBalancer IP
curl http://<LOADBALANCER-IP>

# Test persistent storage
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: longhorn
  resources:
    requests:
      storage: 1Gi
EOF

kubectl get pvc test-pvc

# Test certificate generation
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: test-cert
spec:
  secretName: test-cert-tls
  issuerRef:
    name: selfsigned-issuer
    kind: ClusterIssuer
  dnsNames: [test.homelab.local]
EOF

kubectl describe certificate test-cert
```

## Troubleshooting

### Nodes not joining cluster

```bash
# On control plane, regenerate join command
ssh ubuntu@192.168.1.101
sudo kubeadm token create --print-join-command

# On worker
sudo kubeadm reset -f
sudo <paste-join-command>
```

### Pods not starting

```bash
kubectl top nodes
kubectl describe node <node-name>
kubectl logs <pod-name> -n <namespace>
kubectl describe pod <pod-name> -n <namespace>
```

### Network issues

```bash
# Check Flannel
kubectl logs -n kube-system -l app=flannel
kubectl delete pods -n kube-system -l app=flannel  # Restart
```

### Storage issues

```bash
# Check Longhorn
kubectl get pods -n longhorn-system
kubectl logs -n longhorn-system -l app=longhorn-manager

# Check disk space
just ssh 192.168.1.102
df -h /var/lib/longhorn
```

### MetalLB not assigning IPs

```bash
kubectl logs -n metallb-system -l app=metallb
kubectl get ipaddresspool -n metallb-system
kubectl describe ipaddresspool -n metallb-system homelab-pool
```

## Maintenance

### Update Kubernetes

```bash
# Update versions in packer/variables.pkr.hcl
just rebuild
# Flash new image to SD cards
```

### Update Components

```bash
helm repo update
helm upgrade longhorn longhorn/longhorn -n longhorn-system -f kubernetes/manifests/longhorn-values.yaml
helm upgrade traefik traefik/traefik -n traefik -f kubernetes/manifests/traefik-values.yaml
helm upgrade cert-manager jetstack/cert-manager -n cert-manager --set crds.enabled=true
```

### Scale Workers

```bash
# Flash additional SD card with base image
# Update ansible/inventory.yml
ansible-playbook -i inventory.yml site.yml --limit new-worker
```

### Backup etcd

```bash
just backup-etcd  # Creates timestamped backup
```

## Version Information

- **Ubuntu**: 24.04.1 LTS (Noble Numbat)
- **Kubernetes**: v1.34 (latest stable)
- **Flannel**: v0.25.7
- **MetalLB**: v0.14.9
- **Longhorn**: v1.7.2
- **Traefik**: v3.x (latest)
- **cert-manager**: v1.16.2

See `VERSIONS.md` for detailed compatibility matrix and upgrade paths.

## Features

- ✅ Full Kubernetes (kubeadm, not k3s)
- ✅ ARM64 native performance
- ✅ Reproducible builds (Nix)
- ✅ GitOps-ready structure
- ✅ Automatic HTTPS (Traefik + cert-manager)
- ✅ Distributed storage (Longhorn)
- ✅ LoadBalancer on bare metal (MetalLB)
- ✅ Pre-commit hooks for code quality
- ✅ Comprehensive `just` commands

## Known Limitations

1. **Storage Performance**:
   - SD cards have limited IOPS
   - **Recommendation**: Use USB3 SSDs for better performance and longevity
   - A2-rated SD cards minimum if using SD storage
2. **ARM64 Images**: Some containers don't support ARM64
   - Check: `docker manifest inspect <image>`
3. **Memory**: 8GB RAM per node
   - Set resource limits and monitor usage carefully
   - Consider pod priority classes for critical workloads
4. **Storage Longevity**: SD cards have limited write cycles
   - Regular backups recommended
   - Expect quarterly replacement with SD cards
   - USB3 SSDs significantly more durable

## Next Steps

- Deploy your applications to `kubernetes/apps/`
- Set up GitOps with ArgoCD or Flux
- Configure external DNS
- Implement network policies
- Add Prometheus + Grafana monitoring
- Set up automated backups

## Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Flannel](https://github.com/flannel-io/flannel)
- [MetalLB](https://metallb.universe.tf/)
- [Longhorn](https://longhorn.io/docs/)
- [Traefik](https://doc.traefik.io/traefik/)
- [cert-manager](https://cert-manager.io/docs/)

## License

MIT
