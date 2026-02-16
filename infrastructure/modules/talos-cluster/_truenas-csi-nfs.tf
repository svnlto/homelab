# ==============================================================================
# TrueNAS CSI - Democratic CSI NFS Driver
# ==============================================================================

resource "kubernetes_namespace_v1" "democratic_csi" {
  count = var.deploy_bootstrap && var.truenas_api_key != "" ? 1 : 0

  metadata {
    name = "democratic-csi"
    labels = {
      "pod-security.kubernetes.io/enforce" = "privileged"
    }
  }

  depends_on = [data.talos_cluster_health.cluster]
}

resource "helm_release" "truenas_nfs_csi" {
  count = var.deploy_bootstrap && var.truenas_api_key != "" ? 1 : 0

  name             = "zfs-nfs"
  repository       = "https://democratic-csi.github.io/charts/"
  chart            = "democratic-csi"
  version          = "0.15.1"
  namespace        = kubernetes_namespace_v1.democratic_csi[0].metadata[0].name
  create_namespace = false
  wait             = true
  timeout          = 300

  values = [yamlencode({
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
          provisioner-secret        = {}
          controller-publish-secret = {}
          node-stage-secret         = {}
          node-publish-secret       = {}
          controller-expand-secret  = {}
        }
      }
    ]
    volumeSnapshotClasses = []
    driver = {
      config = {
        driver = "freenas-api-nfs"
        httpConnection = {
          protocol      = split("://", var.truenas_api_url)[0]
          host          = split("/", split("://", var.truenas_api_url)[1])[0]
          port          = 443
          apiKey        = var.truenas_api_key
          allowInsecure = true
        }
        zfs = {
          datasetParentName                  = var.truenas_nfs_dataset
          detachedSnapshotsDatasetParentName = "${var.truenas_nfs_dataset}-snapshots"
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
  })]
}
