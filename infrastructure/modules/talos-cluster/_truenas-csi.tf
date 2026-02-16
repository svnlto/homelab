# ==============================================================================
# TrueNAS CSI - Democratic CSI for NFS and iSCSI Storage
# ==============================================================================

resource "null_resource" "truenas_nfs_csi" {
  count = var.deploy_bootstrap && var.truenas_api_key != "" ? 1 : 0

  triggers = {
    chart_version = "0.15.1"
    api_url       = var.truenas_api_url
    nfs_dataset   = var.truenas_nfs_dataset
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      export KUBECONFIG="${local_sensitive_file.kubeconfig[0].filename}"

      kubectl create namespace democratic-csi --dry-run=client -o yaml | kubectl apply -f -

      helm repo add democratic-csi https://democratic-csi.github.io/charts/ 2>/dev/null || true
      helm repo update democratic-csi
      helm upgrade --install zfs-nfs democratic-csi/democratic-csi \
        --namespace democratic-csi \
        --version 0.15.1 \
        --values - \
        --wait \
        --timeout 5m <<'VALUES'
      ${yamlencode({
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
})}
      VALUES
    EOT
}

depends_on = [data.talos_cluster_health.cluster, local_sensitive_file.kubeconfig]
}

resource "null_resource" "truenas_iscsi_csi" {
  count = var.deploy_bootstrap && var.truenas_api_key != "" && var.truenas_iscsi_portal != "" ? 1 : 0

  triggers = {
    chart_version = "0.15.1"
    api_url       = var.truenas_api_url
    iscsi_portal  = var.truenas_iscsi_portal
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      export KUBECONFIG="${local_sensitive_file.kubeconfig[0].filename}"

      kubectl create namespace democratic-csi --dry-run=client -o yaml | kubectl apply -f -

      helm repo add democratic-csi https://democratic-csi.github.io/charts/ 2>/dev/null || true
      helm repo update democratic-csi
      helm upgrade --install zfs-iscsi democratic-csi/democratic-csi \
        --namespace democratic-csi \
        --version 0.15.1 \
        --values - \
        --wait \
        --timeout 5m <<'VALUES'
      ${yamlencode({
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
})}
      VALUES
    EOT
}

depends_on = [data.talos_cluster_health.cluster, local_sensitive_file.kubeconfig]
}
