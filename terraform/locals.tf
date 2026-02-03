locals {
  # ===========================================================================
  # Proxmox Node Names
  # ===========================================================================
  proxmox_primary   = "din"   # r730xd - Storage + compute
  proxmox_secondary = "grogu" # r630 - Compute-focused

  # ===========================================================================
  # Network Configuration
  # ===========================================================================

  # VLAN Definitions
  # vlan_management = 1  # iDRAC, switch management
  vlan_storage    = 10 # 10GbE NFS/iSCSI, TrueNAS
  vlan_lan        = 20 # VMs, clients, WiFi
  vlan_k8s_shared = 30 # K8s shared services/infrastructure
  vlan_k8s_apps   = 31 # K8s production apps
  vlan_k8s_test   = 32 # K8s testing/staging

  # Network Subnets and Gateways
  # network_management = {
  #   subnet  = "10.10.1.0/24"
  #   gateway = "10.10.1.1"
  #   vlan    = 1
  # }

  # network_storage = {
  #   subnet  = "10.10.10.0/24"
  #   gateway = "10.10.10.1"
  #   vlan    = 10
  # }

  # network_lan = {
  #   subnet  = "192.168.0.0/24"
  #   gateway = "192.168.0.1" # Beryl AX (sorgan)
  #   vlan    = 20
  # }

  # network_k8s_shared = {
  #   subnet  = "10.0.1.0/24"
  #   gateway = "10.0.1.1"
  #   vlan    = 30
  # }

  # network_k8s_apps = {
  #   subnet  = "10.0.2.0/24"
  #   gateway = "10.0.2.1"
  #   vlan    = 31
  # }

  # network_k8s_test = {
  #   subnet  = "10.0.3.0/24"
  #   gateway = "10.0.3.1"
  #   vlan    = 32
  # }

  # Infrastructure IP Addresses
  # ip_router_mgmt             = "10.10.1.1"    # CRS310-8G+2S+IN management
  # ip_router_storage          = "10.10.10.1"   # Router storage gateway
  # ip_router_lan              = "192.168.0.2"  # Router LAN secondary IP
  ip_gateway = "192.168.0.1" # Beryl AX internet gateway
  # ip_pihole                  = "192.168.0.53" # Pi-hole DNS/DHCP
  ip_grogu_mgmt    = "192.168.0.10" # grogu Proxmox management
  ip_grogu_storage = "10.10.10.10"  # grogu storage interface
  ip_grogu_idrac   = "10.10.1.10"   # grogu iDRAC
  ip_din_mgmt      = "192.168.0.11" # din Proxmox management
  ip_din_storage   = "10.10.10.11"  # din storage interface
  ip_din_idrac     = "10.10.1.11"   # din iDRAC
  # ip_truenas_primary         = "192.168.0.13" # TrueNAS primary management
  # ip_truenas_backup          = "192.168.0.14" # TrueNAS backup management
  # ip_truenas_primary_storage = "10.10.10.13"  # TrueNAS primary storage
  # ip_truenas_backup_storage  = "10.10.10.14"  # TrueNAS backup storage

  # DNS Servers
  # dns_servers = ["192.168.0.53", "1.1.1.1"] # Pi-hole, Cloudflare

  # IP Ranges - Management VLAN (10.10.1.0/24)
  # range_mgmt_infrastructure = "10.10.1.1-10.10.1.20"    # Routers, switches
  # range_mgmt_servers        = "10.10.1.21-10.10.1.50"   # Server management
  # range_mgmt_dhcp           = "10.10.1.100-10.10.1.200" # DHCP pool

  # IP Ranges - Storage VLAN (10.10.10.0/24)
  # range_storage_hosts    = "10.10.10.10-10.10.10.12" # Physical hosts
  # range_storage_services = "10.10.10.13-10.10.10.50" # TrueNAS, NFS, iSCSI

  # IP Ranges - LAN VLAN (192.168.0.0/24)
  # range_lan_infrastructure = "192.168.0.1-192.168.0.99"    # Routers, DNS, core
  # range_lan_dhcp           = "192.168.0.100-192.168.0.149" # DHCP pool (Beryl)
  # range_lan_entertainment  = "192.168.0.150-192.168.0.159" # Apple TV, HomePod
  # range_lan_personal       = "192.168.0.160-192.168.0.169" # Laptops, phones
  # range_lan_vms            = "192.168.0.200-192.168.0.250" # VMs/containers

  # Kubernetes Cluster IP Ranges
  # k8s_shared_vip = "10.0.1.10" # kube-vip HA endpoint
  # k8s_shared_control = "10.0.1.11-10.0.1.13"   # Control plane nodes
  # k8s_shared_workers = "10.0.1.21-10.0.1.29"   # Worker nodes
  # k8s_shared_metallb = "10.0.1.100-10.0.1.150" # MetalLB pool

  # k8s_apps_vip     = "10.0.2.10"             # kube-vip HA endpoint
  # k8s_apps_control = "10.0.2.11-10.0.2.13"   # Control plane nodes
  # k8s_apps_workers = "10.0.2.21-10.0.2.29"   # Worker nodes
  # k8s_apps_metallb = "10.0.2.100-10.0.2.150" # MetalLB pool

  # k8s_test_vip     = "10.0.3.10"             # kube-vip HA endpoint
  # k8s_test_control = "10.0.3.11-10.0.3.13"   # Control plane nodes
  # k8s_test_workers = "10.0.3.21-10.0.3.23"   # Worker nodes (smaller)
  # k8s_test_metallb = "10.0.3.100-10.0.3.150" # MetalLB pool

  # Proxmox Bridge Names
  # bridge_storage    = "vmbr10" # VLAN 10 - Storage
  # bridge_lan        = "vmbr20" # VLAN 20 - LAN
  # bridge_k8s_shared = "vmbr30" # VLAN 30 - K8s Shared Services
  # bridge_k8s_apps   = "vmbr31" # VLAN 31 - K8s Apps
  # bridge_k8s_test   = "vmbr32" # VLAN 32 - K8s Test

  # ===========================================================================
  # TrueNAS SCALE Configuration
  # ===========================================================================
  truenas_version  = "25.10.1"
  truenas_url      = "https://download.truenas.com/TrueNAS-SCALE-Goldeye/25.10.1/TrueNAS-SCALE-25.10.1.iso"
  truenas_filename = "TrueNAS-SCALE-25.10.1.iso"
}
