output "arr_stack" {
  description = "Arr stack container details"
  value = {
    vmid = proxmox_virtual_environment_container.arr_stack.vm_id
    ip   = split("/", proxmox_virtual_environment_container.arr_stack.initialization[0].ip_config[0].ipv4[0].address)[0]
    services = {
      prowlarr     = "http://${split("/", proxmox_virtual_environment_container.arr_stack.initialization[0].ip_config[0].ipv4[0].address)[0]}:9696"
      flaresolverr = "http://${split("/", proxmox_virtual_environment_container.arr_stack.initialization[0].ip_config[0].ipv4[0].address)[0]}:8191"
      sonarr       = "http://${split("/", proxmox_virtual_environment_container.arr_stack.initialization[0].ip_config[0].ipv4[0].address)[0]}:8989"
      radarr       = "http://${split("/", proxmox_virtual_environment_container.arr_stack.initialization[0].ip_config[0].ipv4[0].address)[0]}:7878"
      lidarr       = "http://${split("/", proxmox_virtual_environment_container.arr_stack.initialization[0].ip_config[0].ipv4[0].address)[0]}:8686"
      bazarr       = "http://${split("/", proxmox_virtual_environment_container.arr_stack.initialization[0].ip_config[0].ipv4[0].address)[0]}:6767"
      qbittorrent  = "http://${split("/", proxmox_virtual_environment_container.arr_stack.initialization[0].ip_config[0].ipv4[0].address)[0]}:8701"
      sabnzbd      = "http://${split("/", proxmox_virtual_environment_container.arr_stack.initialization[0].ip_config[0].ipv4[0].address)[0]}:8080"
      jellyfin     = "http://${split("/", proxmox_virtual_environment_container.arr_stack.initialization[0].ip_config[0].ipv4[0].address)[0]}:8096"
      jellyseerr   = "http://${split("/", proxmox_virtual_environment_container.arr_stack.initialization[0].ip_config[0].ipv4[0].address)[0]}:5055"
      slskd        = "http://${split("/", proxmox_virtual_environment_container.arr_stack.initialization[0].ip_config[0].ipv4[0].address)[0]}:5030"
    }
  }
}

output "truenas_info" {
  value = {
    vm_id       = proxmox_virtual_environment_vm.truenas.vm_id
    name        = proxmox_virtual_environment_vm.truenas.name
    mac_address = proxmox_virtual_environment_vm.truenas.network_device[0].mac_address
  }
}

output "talos_cluster" {
  description = "Talos Kubernetes cluster information"
  value = {
    cluster_name     = module.homelab_k8s.cluster_name
    cluster_endpoint = module.homelab_k8s.cluster_endpoint
    vip              = module.homelab_k8s.vip_ip
    schematic_id     = module.homelab_k8s.schematic_id
    talos_version    = module.homelab_k8s.talos_version
    k8s_version      = module.homelab_k8s.kubernetes_version

    control_plane = module.homelab_k8s.control_plane_nodes
    workers       = module.homelab_k8s.worker_nodes

    credentials = {
      kubeconfig  = module.homelab_k8s.kubeconfig_path
      talosconfig = module.homelab_k8s.talosconfig_path
    }

    bootstrap_deployed = module.homelab_k8s.bootstrap_deployed
  }
}
