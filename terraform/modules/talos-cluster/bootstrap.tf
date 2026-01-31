# ==============================================================================
# Bootstrap Components - Deployed via Kubernetes/Helm Providers
# ==============================================================================

# ==============================================================================
# Cilium CNI
# ==============================================================================

resource "helm_release" "cilium" {
  count = var.deploy_bootstrap ? 1 : 0

  name             = "cilium"
  repository       = "https://helm.cilium.io/"
  chart            = "cilium"
  version          = "1.16.5"
  namespace        = "kube-system"
  create_namespace = false
  wait             = true
  timeout          = 600

  values = [
    yamlencode({
      ipam = {
        mode = "kubernetes"
      }
      kubeProxyReplacement = true
      k8sServiceHost       = split(":", split("//", var.cluster_endpoint)[1])[0]
      k8sServicePort       = split(":", split("//", var.cluster_endpoint)[1])[1]
      securityContext = {
        capabilities = {
          ciliumAgent = [
            "CHOWN",
            "KILL",
            "NET_ADMIN",
            "NET_RAW",
            "IPC_LOCK",
            "SYS_ADMIN",
            "SYS_RESOURCE",
            "DAC_OVERRIDE",
            "FOWNER",
            "SETGID",
            "SETUID"
          ]
          cleanCiliumState = [
            "NET_ADMIN",
            "SYS_ADMIN",
            "SYS_RESOURCE"
          ]
        }
      }
      cgroup = {
        autoMount = {
          enabled = false
        }
        hostRoot = "/sys/fs/cgroup"
      }
    })
  ]

  depends_on = [talos_machine_bootstrap.cluster]
}

# ==============================================================================
# TrueNAS CSI - NFS (RWX Shared Storage)
# ==============================================================================

resource "kubernetes_namespace" "democratic_csi" {
  count = var.deploy_bootstrap && var.truenas_api_key != "" ? 1 : 0

  metadata {
    name = "democratic-csi"
  }

  depends_on = [helm_release.cilium]
}

resource "helm_release" "truenas_nfs" {
  count = var.deploy_bootstrap && var.truenas_api_key != "" ? 1 : 0

  name             = "zfs-nfs"
  repository       = "https://democratic-csi.github.io/charts/"
  chart            = "democratic-csi"
  version          = "0.14.6"
  namespace        = "democratic-csi"
  create_namespace = false
  wait             = true
  timeout          = 300

  values = [
    yamlencode({
      csiDriver = {
        name = "org.democratic-csi.nfs"
      }
      storageClasses = [
        {
          name                 = "truenas-nfs-rwx"
          defaultClass         = false
          reclaimPolicy        = "Delete"
          volumeBindingMode    = "Immediate"
          allowVolumeExpansion = true
          parameters = {
            fsType = "nfs"
          }
          mountOptions = [
            "nfsvers=4",
            "nconnect=8",
            "hard",
            "noatime",
            "nodiratime"
          ]
          secrets = {
            provisioner-secret        = "democratic-csi-nfs-driver-config"
            controller-publish-secret = "democratic-csi-nfs-driver-config"
            node-stage-secret         = "democratic-csi-nfs-driver-config"
            node-publish-secret       = "democratic-csi-nfs-driver-config"
            controller-expand-secret  = "democratic-csi-nfs-driver-config"
          }
        }
      ]
      volumeSnapshotClasses = [
        {
          name           = "truenas-nfs"
          driver         = "org.democratic-csi.nfs"
          deletionPolicy = "Delete"
          parameters     = {}
        }
      ]
      driver = {
        config = {
          driver = "freenas-nfs"
          httpConnection = {
            protocol      = split("://", var.truenas_api_url)[0]
            host          = split("/", split("://", var.truenas_api_url)[1])[0]
            port          = 443
            apiKey        = var.truenas_api_key
            allowInsecure = true
          }
          zfs = {
            datasetParentName                  = var.truenas_nfs_dataset
            detachedSnapshotsDatasetParentName = "${var.truenas_nfs_dataset}/snapshots"
            datasetEnableQuotas                = true
            datasetEnableReservation           = false
            datasetPermissionsMode             = "0777"
            datasetPermissionsUser             = 0
            datasetPermissionsGroup            = 0
          }
          nfs = {
            shareHost            = split("/", split("://", var.truenas_api_url)[1])[0]
            shareAlldirs         = false
            shareAllowedHosts    = []
            shareAllowedNetworks = []
            shareMaprootUser     = "root"
            shareMaprootGroup    = "wheel"
          }
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace.democratic_csi]
}

# ==============================================================================
# TrueNAS CSI - iSCSI (RWO Block Storage)
# ==============================================================================

resource "helm_release" "truenas_iscsi" {
  count = var.deploy_bootstrap && var.truenas_api_key != "" && var.truenas_iscsi_portal != "" ? 1 : 0

  name             = "zfs-iscsi"
  repository       = "https://democratic-csi.github.io/charts/"
  chart            = "democratic-csi"
  version          = "0.14.6"
  namespace        = "democratic-csi"
  create_namespace = false
  wait             = true
  timeout          = 300

  values = [
    yamlencode({
      csiDriver = {
        name = "org.democratic-csi.iscsi"
      }
      storageClasses = [
        {
          name                 = "truenas-iscsi-rwo"
          defaultClass         = true
          reclaimPolicy        = "Delete"
          volumeBindingMode    = "Immediate"
          allowVolumeExpansion = true
          parameters = {
            fsType = "ext4"
          }
          secrets = {
            provisioner-secret        = "democratic-csi-iscsi-driver-config"
            controller-publish-secret = "democratic-csi-iscsi-driver-config"
            node-stage-secret         = "democratic-csi-iscsi-driver-config"
            node-publish-secret       = "democratic-csi-iscsi-driver-config"
            controller-expand-secret  = "democratic-csi-iscsi-driver-config"
          }
        }
      ]
      volumeSnapshotClasses = [
        {
          name           = "truenas-iscsi"
          driver         = "org.democratic-csi.iscsi"
          deletionPolicy = "Delete"
          parameters     = {}
        }
      ]
      driver = {
        config = {
          driver = "freenas-iscsi"
          httpConnection = {
            protocol      = split("://", var.truenas_api_url)[0]
            host          = split("/", split("://", var.truenas_api_url)[1])[0]
            port          = 443
            apiKey        = var.truenas_api_key
            allowInsecure = true
          }
          zfs = {
            datasetParentName                  = var.truenas_iscsi_dataset
            detachedSnapshotsDatasetParentName = "${var.truenas_iscsi_dataset}/snapshots"
            datasetEnableQuotas                = true
            datasetEnableReservation           = false
            datasetPermissionsMode             = "0600"
            datasetPermissionsUser             = 0
            datasetPermissionsGroup            = 0
          }
          iscsi = {
            targetPortal = var.truenas_iscsi_portal
            namePrefix   = "csi-"
            nameSuffix   = "-${var.cluster_name}"
            targetGroups = [
              {
                targetGroupPortalGroup    = 1
                targetGroupInitiatorGroup = 1
                targetGroupAuthType       = "None"
              }
            ]
            extentInsecureTpc              = true
            extentXenCompat                = false
            extentDisablePhysicalBlocksize = true
            extentBlocksize                = 512
            extentRpm                      = "SSD"
            extentAvailThreshold           = 0
          }
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace.democratic_csi]
}

# ==============================================================================
# MetalLB Load Balancer
# ==============================================================================

resource "kubernetes_namespace" "metallb_system" {
  count = var.deploy_bootstrap && var.metallb_ip_range != "" ? 1 : 0

  metadata {
    name = "metallb-system"
  }

  depends_on = [helm_release.cilium]
}

resource "helm_release" "metallb" {
  count = var.deploy_bootstrap && var.metallb_ip_range != "" ? 1 : 0

  name             = "metallb"
  repository       = "https://metallb.github.io/metallb"
  chart            = "metallb"
  version          = "0.14.9"
  namespace        = "metallb-system"
  create_namespace = false
  wait             = true
  timeout          = 300

  depends_on = [kubernetes_namespace.metallb_system]
}

resource "kubernetes_manifest" "metallb_ippool" {
  count = var.deploy_bootstrap && var.metallb_ip_range != "" ? 1 : 0

  manifest = {
    apiVersion = "metallb.io/v1beta1"
    kind       = "IPAddressPool"
    metadata = {
      name      = "default-pool"
      namespace = "metallb-system"
    }
    spec = {
      addresses = [var.metallb_ip_range]
    }
  }

  depends_on = [helm_release.metallb]
}

resource "kubernetes_manifest" "metallb_l2advertisement" {
  count = var.deploy_bootstrap && var.metallb_ip_range != "" ? 1 : 0

  manifest = {
    apiVersion = "metallb.io/v1beta1"
    kind       = "L2Advertisement"
    metadata = {
      name      = "default"
      namespace = "metallb-system"
    }
    spec = {
      ipAddressPools = ["default-pool"]
    }
  }

  depends_on = [kubernetes_manifest.metallb_ippool]
}
