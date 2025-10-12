# Kubernetes Manifests

Component configurations for the cluster.

## Installation Order

After cluster deployment with Ansible:

1. **Flannel CNI** - Installed automatically by Ansible
2. **MetalLB** - `just k8s-install-metallb`
3. **Longhorn** - `just k8s-install-longhorn`
4. **cert-manager** - `just k8s-install-certmanager`
5. **Traefik** - `just k8s-install-traefik`

Or install all at once: `just k8s-install-all`

## Configuration

### MetalLB (`metallb-config.yaml`)

Update IP range to match your network:

```yaml
addresses:
  - 192.168.1.200-192.168.1.220
```

### Longhorn (`longhorn-values.yaml`)

- Storage path: `/var/lib/longhorn`
- Replica count: 2 (adjust for your cluster)
- UI: `http://longhorn.local`

### cert-manager (`cert-manager.yaml`)

Update email for Let's Encrypt:

```yaml
email: your-email@example.com
```

Issuers:

- `letsencrypt-staging` - Testing
- `letsencrypt-prod` - Production
- `selfsigned-issuer` - Internal services

### Traefik (`traefik-values.yaml`)

Update email and domains:

```yaml
additionalArguments:
  - "--certificatesresolvers.letsencrypt.acme.email=your-email@example.com"
```

Dashboard: `https://traefik.local`

## Verification

```bash
kubectl get pods -A
kubectl get storageclass
kubectl get clusterissuer
kubectl get svc -A | grep LoadBalancer
```
