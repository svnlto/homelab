# Component Versions

This file tracks all software versions used in the homelab setup.

**Last Updated**: October 2025

## Base Operating System

- **Ubuntu Server**: 24.04.1 LTS (Noble Numbat)
- **Architecture**: ARM64 (aarch64)
- **Kernel**: Linux 6.8+ (included with Ubuntu 24.04)

## Kubernetes Core

- **Kubernetes**: v1.34 (latest stable as of Oct 2025)
- **Container Runtime**: containerd (from Ubuntu repositories)
- **CNI Plugin**: Flannel v0.25.7

## Cluster Components

### LoadBalancer

- **MetalLB**: v0.14.9
- **Mode**: Layer 2 (ARP)

### Storage

- **Longhorn**: v1.7.2
- **Default Replica Count**: 2
- **Storage Class**: longhorn (default)

### Ingress

- **Traefik**: v3.x (latest from Helm chart)
- **Chart Version**: Latest stable
- **Repository**: <https://traefik.github.io/charts>

### Certificates

- **cert-manager**: v1.16.2
- **ACME**: Let's Encrypt (staging + production)
- **Chart Repository**: <https://charts.jetstack.io>

## Development Tools (Nix)

- **Packer**: Latest from nixpkgs-unstable
- **Ansible**: Latest from nixpkgs-unstable
- **kubectl**: Latest from nixpkgs-unstable
- **Helm**: Latest from nixpkgs-unstable
- **k9s**: Latest from nixpkgs-unstable
- **QEMU**: Latest from nixpkgs-unstable

## Packer Plugins

- **packer-plugin-arm-image**: v0.2.7
- **Source**: github.com/solo-io/arm-image

## Network Configuration

### Default CIDRs

- **Pod Network**: 10.244.0.0/16 (Flannel default)
- **Service CIDR**: 10.96.0.0/12 (Kubernetes default)
- **MetalLB IP Pool**: 192.168.1.200-192.168.1.220 (customize for your network)

### Default Ports

- **API Server**: 6443
- **Traefik HTTP**: 80
- **Traefik HTTPS**: 443
- **Longhorn UI**: 80 (via ingress)
- **Traefik Dashboard**: 443 (via ingress)

## Recommended Hardware Specifications

### Control Plane Node

- **Model**: Raspberry Pi 4
- **RAM**: 8GB (minimum 4GB)
- **Storage**: 32GB+ MicroSD (64GB recommended)
- **Network**: Gigabit Ethernet

### Worker Nodes

- **Model**: Raspberry Pi 4
- **RAM**: 4GB+ (8GB recommended for Longhorn)
- **Storage**: 64GB+ MicroSD (for Longhorn storage)
- **Network**: Gigabit Ethernet

## Update Strategy

### Kubernetes Updates

- **Strategy**: Image rebuild with Packer
- **Frequency**: Follow Kubernetes release cycle (quarterly)
- **Support Window**: 3 minor versions (approximately 1 year)

### Component Updates

- **MetalLB**: Update via kubectl apply
- **Longhorn**: Update via Helm upgrade
- **Traefik**: Update via Helm upgrade
- **cert-manager**: Update via Helm upgrade

### Ubuntu Updates

- **Security Updates**: Applied in Packer build
- **Major Version**: Rebuild image every 2 years (LTS cycle)

## Compatibility Matrix

| Component | Kubernetes 1.34 | ARM64 | Ubuntu 24.04 |
|-----------|----------------|-------|--------------|
| containerd | ✅ | ✅ | ✅ |
| Flannel | ✅ | ✅ | ✅ |
| MetalLB | ✅ | ✅ | ✅ |
| Longhorn | ✅ | ✅ | ✅ |
| Traefik | ✅ | ✅ | ✅ |
| cert-manager | ✅ | ✅ | ✅ |

## Known Limitations

1. **Longhorn Performance**: Block storage on SD cards has limited IOPS
   - **Mitigation**: Use high-quality SD cards (A2 rating) or USB3 SSDs

2. **Raspberry Pi 4 RAM**: Limited to 8GB maximum
   - **Impact**: Limits number of pods per node
   - **Recommendation**: Monitor memory usage, set resource limits

3. **ARM64 Image Availability**: Some container images don't support ARM64
   - **Check before deploying**: `docker manifest inspect <image>`
   - **Alternative**: Build multi-arch images

4. **SD Card Longevity**: SD cards have limited write cycles
   - **Mitigation**: Use log rotation, monitor disk health
   - **Recommendation**: Regular backups, quarterly SD card replacement

## Changelog

### October 2025

- Initial setup with Kubernetes v1.34
- Ubuntu 24.04 LTS as base OS
- Replaced Calico with Flannel (lighter weight)
- Added Traefik instead of ingress-nginx
- Added Longhorn for persistent storage
- Added cert-manager for TLS automation

## Version Check Commands

```bash
# Kubernetes version
kubectl version --short

# Node versions
kubectl get nodes -o wide

# Component versions
helm list -A

# Container runtime version
ssh ubuntu@<node-ip> "containerd --version"

# Flannel version
kubectl get pods -n kube-system -l app=flannel -o jsonpath='{.items[0].spec.containers[0].image}'

# MetalLB version
kubectl get deployment -n metallb-system controller -o jsonpath='{.spec.template.spec.containers[0].image}'

# Longhorn version
helm list -n longhorn-system

# Traefik version
helm list -n traefik

# cert-manager version
helm list -n cert-manager
```

## Upgrade Paths

### Minor Kubernetes Updates (e.g., 1.34.x → 1.34.y)

```bash
# Rebuild Packer image with updated version
cd packer
# Update variables.pkr.hcl
packer build rpi-k8s-base.pkr.hcl

# Reflash SD cards with new image
# Or use kubeadm upgrade (more complex)
```

### Components

```bash
# Update Helm repositories
helm repo update

# Upgrade Longhorn
helm upgrade longhorn longhorn/longhorn -n longhorn-system -f longhorn-values.yaml

# Upgrade Traefik
helm upgrade traefik traefik/traefik -n traefik -f traefik-values.yaml

# Upgrade cert-manager
helm upgrade cert-manager jetstack/cert-manager -n cert-manager --set crds.enabled=true

# Update MetalLB (check release notes first)
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/vX.Y.Z/config/manifests/metallb-native.yaml
```

## Support & EOL Dates

- **Ubuntu 24.04 LTS**: Support until April 2029 (5 years)
- **Kubernetes 1.34**: Support until ~December 2025 (approximately 14 months)
- **Raspberry Pi 4**: Still actively supported by Raspberry Pi Foundation

## References

- Kubernetes Releases: <https://kubernetes.io/releases/>
- Ubuntu Releases: <https://ubuntu.com/about/release-cycle>
- Flannel Documentation: <https://github.com/flannel-io/flannel>
- MetalLB Documentation: <https://metallb.universe.tf/>
- Longhorn Documentation: <https://longhorn.io/docs/>
- Traefik Documentation: <https://doc.traefik.io/traefik/>
- cert-manager Documentation: <https://cert-manager.io/docs/>
