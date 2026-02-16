# ==============================================================================
# MetalLB Load Balancer - L2 Mode for Bare Metal LoadBalancer Services
# ==============================================================================

locals {
  metallb_version = "v0.15.3"
  metallb_config  = <<-YAML
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
    - ${var.metallb_ip_range}
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
spec:
  ipAddressPools:
    - default-pool
YAML
}

resource "null_resource" "metallb" {
  count = var.deploy_bootstrap && var.metallb_ip_range != "" ? 1 : 0

  triggers = {
    version  = local.metallb_version
    ip_range = var.metallb_ip_range
    config   = sha256(local.metallb_config)
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      export KUBECONFIG="${local_sensitive_file.kubeconfig[0].filename}"

      echo "Installing MetalLB ${local.metallb_version}..."
      kubectl apply -f "https://raw.githubusercontent.com/metallb/metallb/${local.metallb_version}/config/manifests/metallb-native.yaml"

      echo "Waiting for MetalLB controller deployment to be available..."
      kubectl -n metallb-system rollout status deployment/controller --timeout=300s

      echo "Waiting for MetalLB speaker daemonset to be ready..."
      kubectl -n metallb-system rollout status daemonset/speaker --timeout=300s

      echo "Applying MetalLB IP pool configuration..."
      kubectl apply -f - <<'EOF'
${local.metallb_config}
EOF

      echo "MetalLB installed and configured."
    EOT
  }

  depends_on = [data.talos_cluster_health.cluster, local_sensitive_file.kubeconfig]
}
