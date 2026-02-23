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

locals {
  nfs_csi_common = {
    repository       = "https://democratic-csi.github.io/charts/"
    chart            = "democratic-csi"
    version          = "0.15.1"
    create_namespace = false
    wait             = true
    timeout          = 300
  }

  truenas_http_connection = {
    protocol      = split("://", var.truenas_api_url)[0]
    host          = split("/", split("://", var.truenas_api_url)[1])[0]
    port          = 443
    apiKey        = var.truenas_api_key
    allowInsecure = true
  }

  nfs_share_config = {
    shareHost            = split("/", split("://", var.truenas_api_url)[1])[0]
    shareAlldirs         = false
    shareAllowedHosts    = []
    shareAllowedNetworks = []
    shareMaprootUser     = "root"
    shareMaprootGroup    = "wheel"
  }

  nfs_mount_options = [
    "nfsvers=4",
    "nconnect=8",
    "hard",
    "noatime",
    "nodiratime"
  ]

  nfs_storage_class_secrets = {
    provisioner-secret        = {}
    controller-publish-secret = {}
    node-stage-secret         = {}
    node-publish-secret       = {}
    controller-expand-secret  = {}
  }
}

# --- Bulk pool (HDD) ---
resource "helm_release" "truenas_nfs_csi" {
  count = var.deploy_bootstrap && var.truenas_api_key != "" ? 1 : 0

  name             = "zfs-nfs"
  repository       = local.nfs_csi_common.repository
  chart            = local.nfs_csi_common.chart
  version          = local.nfs_csi_common.version
  namespace        = kubernetes_namespace_v1.democratic_csi[0].metadata[0].name
  create_namespace = local.nfs_csi_common.create_namespace
  wait             = local.nfs_csi_common.wait
  timeout          = local.nfs_csi_common.timeout

  values = [yamlencode({
    csiDriver = {
      name = "org.democratic-csi.nfs"
    }
    storageClasses = [
      {
        name                 = "truenas-nfs-bulk"
        defaultClass         = false
        reclaimPolicy        = "Delete"
        volumeBindingMode    = "Immediate"
        allowVolumeExpansion = true
        parameters = {
          fsType = "nfs"
        }
        mountOptions = local.nfs_mount_options
        secrets      = local.nfs_storage_class_secrets
      }
    ]
    volumeSnapshotClasses = []
    driver = {
      config = {
        driver         = "freenas-api-nfs"
        httpConnection = local.truenas_http_connection
        zfs = {
          datasetParentName                  = var.truenas_nfs_dataset
          detachedSnapshotsDatasetParentName = "${var.truenas_nfs_dataset}-snapshots"
          datasetEnableQuotas                = true
          datasetEnableReservation           = false
          datasetPermissionsMode             = "0777"
          datasetPermissionsUser             = 0
          datasetPermissionsGroup            = 0
        }
        nfs = local.nfs_share_config
      }
    }
  })]
}

# --- Fast pool (10K SAS) ---
resource "helm_release" "truenas_nfs_fast_csi" {
  count = var.deploy_bootstrap && var.truenas_api_key != "" && var.truenas_nfs_fast_dataset != "" ? 1 : 0

  name             = "zfs-nfs-fast"
  repository       = local.nfs_csi_common.repository
  chart            = local.nfs_csi_common.chart
  version          = local.nfs_csi_common.version
  namespace        = kubernetes_namespace_v1.democratic_csi[0].metadata[0].name
  create_namespace = local.nfs_csi_common.create_namespace
  wait             = local.nfs_csi_common.wait
  timeout          = local.nfs_csi_common.timeout

  values = [yamlencode({
    csiDriver = {
      name = "org.democratic-csi.nfs-fast"
    }
    storageClasses = [
      {
        name                 = "truenas-nfs-fast"
        defaultClass         = false
        reclaimPolicy        = "Retain"
        volumeBindingMode    = "Immediate"
        allowVolumeExpansion = true
        parameters = {
          fsType = "nfs"
        }
        mountOptions = local.nfs_mount_options
        secrets      = local.nfs_storage_class_secrets
      }
    ]
    volumeSnapshotClasses = []
    driver = {
      config = {
        driver         = "freenas-api-nfs"
        httpConnection = local.truenas_http_connection
        zfs = {
          datasetParentName                  = var.truenas_nfs_fast_dataset
          detachedSnapshotsDatasetParentName = "${var.truenas_nfs_fast_dataset}-snapshots"
          datasetEnableQuotas                = true
          datasetEnableReservation           = false
          datasetPermissionsMode             = "0777"
          datasetPermissionsUser             = 0
          datasetPermissionsGroup            = 0
        }
        nfs = local.nfs_share_config
      }
    }
  })]
}

# --- Scratch pool (temporary/ephemeral) ---
resource "helm_release" "truenas_nfs_scratch_csi" {
  count = var.deploy_bootstrap && var.truenas_api_key != "" && var.truenas_nfs_scratch_dataset != "" ? 1 : 0

  name             = "zfs-nfs-scratch"
  repository       = local.nfs_csi_common.repository
  chart            = local.nfs_csi_common.chart
  version          = local.nfs_csi_common.version
  namespace        = kubernetes_namespace_v1.democratic_csi[0].metadata[0].name
  create_namespace = local.nfs_csi_common.create_namespace
  wait             = local.nfs_csi_common.wait
  timeout          = local.nfs_csi_common.timeout

  values = [yamlencode({
    csiDriver = {
      name = "org.democratic-csi.nfs-scratch"
    }
    storageClasses = [
      {
        name                 = "truenas-nfs-scratch"
        defaultClass         = false
        reclaimPolicy        = "Delete"
        volumeBindingMode    = "Immediate"
        allowVolumeExpansion = true
        parameters = {
          fsType = "nfs"
        }
        mountOptions = local.nfs_mount_options
        secrets      = local.nfs_storage_class_secrets
      }
    ]
    volumeSnapshotClasses = []
    driver = {
      config = {
        driver         = "freenas-api-nfs"
        httpConnection = local.truenas_http_connection
        zfs = {
          datasetParentName                  = var.truenas_nfs_scratch_dataset
          detachedSnapshotsDatasetParentName = "${var.truenas_nfs_scratch_dataset}-snapshots"
          datasetEnableQuotas                = true
          datasetEnableReservation           = false
          datasetPermissionsMode             = "0777"
          datasetPermissionsUser             = 0
          datasetPermissionsGroup            = 0
        }
        nfs = local.nfs_share_config
      }
    }
  })]
}
