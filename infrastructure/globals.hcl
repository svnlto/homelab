# ==============================================================================
# Global Configuration - Single Source of Truth
# ==============================================================================
# This file contains all shared configuration used across Proxmox and MikroTik
# infrastructure. All Terragrunt modules include this file to access these values.

locals {
  environments = {
    prod = {
      name        = "production"
      description = "Production environment"
      pools = {
        storage = "prod-storage"
        compute = "prod-compute"
      }
    }
    dev = {
      name        = "development"
      description = "Development environment"
      pools = {
        storage = "dev-storage"
        compute = "dev-compute"
      }
    }
  }
  vlans = {
    management = {
      id          = 1
      name        = "management"
      subnet      = "10.10.1.0/24"
      gateway     = "10.10.1.1"
      description = "iDRAC, switch management"
    }

    storage = {
      id          = 10
      name        = "storage"
      subnet      = "10.10.10.0/24"
      gateway     = "10.10.10.1"
      description = "10GbE NFS/iSCSI, TrueNAS"
    }

    lan = {
      id          = 20
      name        = "lan"
      subnet      = "192.168.0.0/24"
      gateway     = "192.168.0.1"
      description = "VMs, clients, WiFi (Beryl AX gateway)"
    }

    k8s_shared = {
      id          = 30
      name        = "k8s-shared"
      subnet      = "10.0.1.0/24"
      gateway     = "10.0.1.1"
      description = "K8s shared services/infrastructure"
    }

    k8s_apps = {
      id          = 31
      name        = "k8s-apps"
      subnet      = "10.0.2.0/24"
      gateway     = "10.0.2.1"
      description = "K8s production apps"
    }

    k8s_test = {
      id          = 32
      name        = "k8s-test"
      subnet      = "10.0.3.0/24"
      gateway     = "10.0.3.1"
      description = "K8s testing/staging"
    }
  }

  infrastructure_ips = {
    # Gateway (Beryl AX)
    gateway = "192.168.0.1"

    # DNS
    pihole = "192.168.0.53"

    # MikroTik CRS Router (to be configured)
    router_mgmt    = "10.10.1.2"   # Management VLAN
    router_lan     = "192.168.0.3" # MikroTik switch/router
    router_storage = "10.10.10.1"  # Storage VLAN gateway

    # Proxmox Nodes
    grogu_mgmt    = "192.168.0.10"
    grogu_storage = "10.10.10.10"
    grogu_idrac   = "10.10.1.10"

    din_mgmt    = "192.168.0.11"
    din_storage = "10.10.10.11"
    din_idrac   = "10.10.1.11"

    # TrueNAS
    truenas_primary_mgmt    = "192.168.0.13"
    truenas_primary_storage = "10.10.10.13"
    truenas_backup_mgmt     = "192.168.0.14"
    truenas_backup_storage  = "10.10.10.14"
  }

  dhcp_pools = {
    lan = {
      start = "192.168.0.100"
      end   = "192.168.0.149"
      lease = "24h"
      dns   = ["192.168.0.53"]
    }

    k8s_shared = {
      start = "10.0.1.100"
      end   = "10.0.1.199"
      lease = "12h"
      dns   = ["192.168.0.53"]
    }

    k8s_apps = {
      start = "10.0.2.100"
      end   = "10.0.2.199"
      lease = "12h"
      dns   = ["192.168.0.53"]
    }

    k8s_test = {
      start = "10.0.3.100"
      end   = "10.0.3.199"
      lease = "6h"
      dns   = ["192.168.0.53"]
    }
  }

  k8s_clusters = {
    shared = {
      vip           = "10.0.1.10"
      control_start = "10.0.1.11"
      control_end   = "10.0.1.13"
      worker_start  = "10.0.1.21"
      worker_end    = "10.0.1.29"
      metallb_start = "10.0.1.100"
      metallb_end   = "10.0.1.150"
    }

    apps = {
      vip           = "10.0.2.10"
      control_start = "10.0.2.11"
      control_end   = "10.0.2.13"
      worker_start  = "10.0.2.21"
      worker_end    = "10.0.2.29"
      metallb_start = "10.0.2.100"
      metallb_end   = "10.0.2.150"
    }

    test = {
      vip           = "10.0.3.10"
      control_start = "10.0.3.11"
      control_end   = "10.0.3.13"
      worker_start  = "10.0.3.21"
      worker_end    = "10.0.3.23"
      metallb_start = "10.0.3.100"
      metallb_end   = "10.0.3.150"
    }
  }

  mikrotik = {
    hostname = "crs-router"
    api_url  = "https://192.168.0.3" # MikroTik REST API (after configuration)

    # Physical interfaces (to be configured based on actual hardware)
    interfaces = {
      wan_to_beryl = "ether1"       # Uplink to Beryl AX gateway
      pihole       = "ether2"       # Raspberry Pi
      sfp_plus1    = "sfp-sfpplus1" # grogu 10GbE
      sfp_plus2    = "sfp-sfpplus2" # din 10GbE
    }

    bridge_name = "bridge-vlans"
  }

  proxmox = {
    nodes = {
      primary   = "din"   # r730xd - Storage + compute
      secondary = "grogu" # r630 - Compute-focused
    }

    api_url = "https://192.168.0.175:8006/api2/json" # din node (current IP)

    # Bridge names for VLAN-aware networking
    bridges = {
      storage    = "vmbr10"
      lan        = "vmbr20"
      k8s_shared = "vmbr30"
      k8s_apps   = "vmbr31"
      k8s_test   = "vmbr32"
    }

    # VM template ID
    template_vm_id = 9000

    # PCIe Resource Mappings (configured in Proxmox UI)
    resource_mappings = {
      truenas_h330 = "truenas-h330" # Dell H330 Mini on din (5×8TB internal drives)
      truenas_lsi  = "truenas-lsi"  # LSI 9201-8e on din (MD1220 shelf, 24×900GB)
      md1200_hba   = "md1200-hba"   # md1200 controller on grogu (8×3tb)
      md1220_hba   = "md1220-hba"   # md1220 controller on din (11×3tb)
    }
  }

  truenas = {
    version  = "25.10.1"
    url      = "https://download.truenas.com/TrueNAS-SCALE-Goldeye/25.10.1/TrueNAS-SCALE-25.10.1.iso"
    filename = "TrueNAS-SCALE-25.10.1.iso"
    checksum = "sha256:PLACEHOLDER" # Add actual checksum

    primary = {
      vm_id     = 300
      node_name = "din"
      hostname  = "truenas-server"
      cores     = 8
      memory_mb = 32768
      disks = {
        boot_size_gb = 32
      }
    }

    backup = {
      vm_id     = 301
      node_name = "grogu"
      hostname  = "truenas-backup"
      cores     = 6
      memory_mb = 24576
      disks = {
        boot_size_gb = 32
      }
    }
  }

  versions = {
    terraform  = "1.14.1"
    terragrunt = "0.71.6"
    packer     = "1.14.3"
    ansible    = "latest" # From nixpkgs-unstable
  }

  common_tags = {
    managed_by = "terragrunt"
    project    = "homelab"
    backup     = "restic-b2"
  }

  # Backblaze B2 Remote State Configuration
  # S3-compatible backend for Terragrunt state storage
  backend = {
    bucket_name = "svnlto-homelab-terraform-state"
    region      = "eu-central-003"
    endpoint    = "s3.eu-central-003.backblazeb2.com"
  }
}
