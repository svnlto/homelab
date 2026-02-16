# ==============================================================================
# TrueNAS CSI - Democratic CSI iSCSI Driver
# ==============================================================================

resource "helm_release" "truenas_iscsi_csi" {
  count = var.deploy_bootstrap && var.truenas_api_key != "" && var.truenas_iscsi_portal != "" ? 1 : 0

  name             = "zfs-iscsi"
  repository       = "https://democratic-csi.github.io/charts/"
  chart            = "democratic-csi"
  version          = "0.15.1"
  namespace        = kubernetes_namespace_v1.democratic_csi[0].metadata[0].name
  create_namespace = false
  wait             = true
  timeout          = 300

  values = [yamlencode({
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
        driver = "freenas-api-iscsi"
        httpConnection = {
          protocol      = split("://", var.truenas_api_url)[0]
          host          = split("/", split("://", var.truenas_api_url)[1])[0]
          port          = 443
          apiKey        = var.truenas_api_key
          allowInsecure = true
        }
        zfs = {
          datasetParentName                  = var.truenas_iscsi_dataset
          detachedSnapshotsDatasetParentName = "${var.truenas_iscsi_dataset}-snapshots"
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
  })]
}
