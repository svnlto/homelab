output "arr_server_ipv4" {
  description = "IPv4 addresses of the arr server"
  value       = module.arr_server.ipv4_addresses
}

output "observability_server_ipv4" {
  description = "IPv4 addresses of the observability server"
  value       = module.observability_server.ipv4_addresses
}

output "truenas_info" {
  value = {
    vm_id      = proxmox_virtual_environment_vm.truenas.vm_id
    name       = proxmox_virtual_environment_vm.truenas.name
    ip_address = "192.168.1.74"
    web_ui     = "http://192.168.1.74"
    disks = {
      boot  = "virtio0 (32GB) - OS"
      data1 = "scsi1 (100GB) - ZFS"
      data2 = "scsi2 (100GB) - ZFS"
      data3 = "scsi3 (100GB) - ZFS"
    }
    total_storage = "300GB raw (200GB usable in RAIDZ1, 100GB in mirror)"
    memory_gb     = 16
    cores         = 4
  }
}
