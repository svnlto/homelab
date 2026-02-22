# Global configuration shared across all Terragrunt modules.
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
      description = "VMs, clients, WiFi"
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
    gateway = "192.168.8.1"
    pihole  = "192.168.0.53"

    router_mgmt    = "10.10.1.2"
    router_lan     = "192.168.0.1"
    router_storage = "10.10.10.1"

    grogu_mgmt    = "192.168.0.10"
    grogu_storage = "10.10.10.10"
    grogu_idrac   = "10.10.1.10"

    din_mgmt    = "192.168.0.11"
    din_storage = "10.10.10.11"
    din_idrac   = "10.10.1.11"

    qdevice = "192.168.0.54"

    truenas_primary_mgmt    = "192.168.0.13"
    truenas_primary_storage = "10.10.10.13"
    truenas_backup_mgmt     = "192.168.0.14"
    truenas_backup_storage  = "10.10.10.14"
  }

  dhcp_pools = {
    lan = {
      start = "192.168.0.100"
      end   = "192.168.0.149"
      lease = "1d"
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

  dns = {
    domain            = "svenlito.com"
    homelab_subdomain = "h"
  }

  k8s_clusters = {
    shared = {
      vip                = "10.0.1.10"
      control_start      = "10.0.1.11"
      control_end        = "10.0.1.13"
      worker_start       = "10.0.1.21"
      worker_end         = "10.0.1.29"
      metallb_start      = "10.0.1.100"
      metallb_end        = "10.0.1.150"
      fqdn_suffix        = "shared.h.svenlito.com"
      tailscale_hostname = "traefik-shared"
    }

    test = {
      vip                = "10.0.3.10"
      control_start      = "10.0.3.11"
      control_end        = "10.0.3.13"
      worker_start       = "10.0.3.21"
      worker_end         = "10.0.3.23"
      metallb_start      = "10.0.3.100"
      metallb_end        = "10.0.3.150"
      fqdn_suffix        = "test.h.svenlito.com"
      tailscale_hostname = "traefik-test"
    }
  }

  mikrotik = {
    hostname = "nevarro"
    api_url  = "https://192.168.0.1"

    wan = {
      interface = "ether1"
      address   = "192.168.8.2/24"
      gateway   = "192.168.8.1"
      comment   = "WAN to O2 Homespot"
    }

    access_ports = {
      pihole      = { interface = "ether2", pvid = 20, comment = "Pi-hole DNS" }
      beryl_ap    = { interface = "ether3", pvid = 20, comment = "Beryl AX WiFi AP" }
      din_idrac   = { interface = "ether4", pvid = 1, comment = "din iDRAC" }
      grogu_idrac = { interface = "ether5", pvid = 1, comment = "grogu iDRAC" }
      qdevice     = { interface = "ether6", pvid = 20, comment = "Proxmox QDevice" }
    }

    trunk_ports = {
      sfp_plus1 = { interface = "sfp-sfpplus1", comment = "grogu 10GbE" }
      sfp_plus2 = { interface = "sfp-sfpplus2", comment = "din 10GbE" }
    }

    bridge_name = "bridge-vlans"

    allowed_management_subnets = "192.168.0.0/24,10.10.1.0/24"

    qos = {
      download_limit = "95M"
      upload_limit   = "40M"
      bulk_hosts     = ["10.0.1.0/24"]
    }
  }

  proxmox = {
    nodes = {
      primary   = "din"
      secondary = "grogu"
    }

    api_url = "https://192.168.0.11:8006/api2/json"

    bridges = {
      storage    = "vmbr10"
      lan        = "vmbr20"
      k8s_shared = "vmbr30"
      k8s_apps   = "vmbr31"
      k8s_test   = "vmbr32"
    }

    template_vm_id = 9000

    # Proxmox PCI resource mappings (managed by Ansible, see host_vars/)
    resource_mappings = {
      truenas_h330 = "truenas-h330"
      truenas_lsi  = "truenas-lsi"
      truenas_h241 = "truenas-h241"
      arc_a310     = "arc-a310"
    }
  }

  truenas = {
    version  = "25.10.1"
    url      = "https://download.truenas.com/TrueNAS-SCALE-Goldeye/25.10.1/TrueNAS-SCALE-25.10.1.iso"
    filename = "TrueNAS-SCALE-25.10.1.iso"
    checksum = "d7e325c4e5416f52060f87ee337ae5a4c9c7bb16d34bfcad5e4a69c265ceb5d6"

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

  nixos = {
    iso_url  = "https://releases.nixos.org/nixos/unstable/nixos-26.05pre942779.d6c719321308/nixos-minimal-26.05pre942779.d6c719321308-x86_64-linux.iso"
    filename = "nixos-minimal-x86_64-linux.iso"
  }

  talos = {
    version = "v1.12.2"
    # Schematic includes: siderolabs/i915-ucode, siderolabs/intel-ucode,
    # siderolabs/iscsi-tools, siderolabs/qemu-guest-agent
    schematic_id = "930a00fbcce4d3bcd531c92e13d24412df7b676f818004fbbdfeb693e4dcb649"
  }

  versions = {
    terraform  = "1.14.1"
    terragrunt = "0.71.6"
    ansible    = "latest"
  }

  common_tags = {
    managed_by = "terragrunt"
    project    = "homelab"
    backup     = "restic-b2"
  }

  # Backblaze B2 state backend (S3-compatible)
  backend = {
    bucket_name = "svnlto-homelab-terraform-state"
    region      = "eu-central-003"
    endpoint    = "s3.eu-central-003.backblazeb2.com"
  }
}
