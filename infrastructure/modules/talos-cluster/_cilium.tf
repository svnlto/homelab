# ==============================================================================
# Cilium CNI Configuration
# ==============================================================================

data "helm_template" "cilium" {
  count = var.deploy_bootstrap ? 1 : 0

  namespace    = "kube-system"
  name         = "cilium"
  repository   = "https://helm.cilium.io"
  chart        = "cilium"
  version      = "1.19.1"
  kube_version = var.kubernetes_version

  set = [
    {
      name  = "ipam.mode"
      value = "kubernetes"
    },
    {
      name  = "securityContext.capabilities.ciliumAgent"
      value = "{CHOWN,KILL,NET_ADMIN,NET_RAW,IPC_LOCK,SYS_ADMIN,SYS_RESOURCE,DAC_OVERRIDE,FOWNER,SETGID,SETUID}"
    },
    {
      name  = "securityContext.capabilities.cleanCiliumState"
      value = "{NET_ADMIN,SYS_ADMIN,SYS_RESOURCE}"
    },
    {
      name  = "cgroup.autoMount.enabled"
      value = "false"
    },
    {
      name  = "cgroup.hostRoot"
      value = "/sys/fs/cgroup"
    },
    {
      name  = "k8sServiceHost"
      value = "localhost"
    },
    {
      name  = "k8sServicePort"
      value = "7445"
    },
    {
      name  = "kubeProxyReplacement"
      value = "true"
    },
    {
      name  = "devices"
      value = "{eth0}"
    },
    {
      name  = "nodePort.directRoutingDevice"
      value = "eth0"
    },
    {
      name  = "socketLB.enabled"
      value = "true"
    }
  ]
}
