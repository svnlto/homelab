# ==============================================================================
# TrueNAS CSI - Democratic CSI for NFS and iSCSI Storage
# ==============================================================================

# ==============================================================================
# Democratic CSI Namespace
# ==============================================================================

resource "kubernetes_namespace_v1" "democratic_csi" {
  count = var.deploy_bootstrap && var.truenas_api_key != "" ? 1 : 0

  metadata {
    name = "democratic-csi"
  }

  depends_on = [talos_machine_bootstrap.cluster]
}

# ==============================================================================
# TrueNAS NFS CSI (RWX Shared Storage)
# ==============================================================================

resource "helm_release" "truenas_nfs" {
  count = var.deploy_bootstrap && var.truenas_api_key != "" ? 1 : 0

  name             = "zfs-nfs"
  repository       = "https://democratic-csi.github.io/charts/"
  chart            = "democratic-csi"
  version          = "0.15.1"
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

  depends_on = [kubernetes_namespace_v1.democratic_csi]
}

# ==============================================================================
# TrueNAS iSCSI CSI (RWO Block Storage)
# ==============================================================================

resource "helm_release" "truenas_iscsi" {
  count = var.deploy_bootstrap && var.truenas_api_key != "" && var.truenas_iscsi_portal != "" ? 1 : 0

  name             = "zfs-iscsi"
  repository       = "https://democratic-csi.github.io/charts/"
  chart            = "democratic-csi"
  version          = "0.15.1"
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

  depends_on = [kubernetes_namespace_v1.democratic_csi]
}
