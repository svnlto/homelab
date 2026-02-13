# ==============================================================================
# Dev Test Cluster - Talos Kubernetes
# ==============================================================================

module "test_cluster" {
  source = "../../../modules/talos-cluster"

  # Cluster Identity
  cluster_name     = var.cluster_name
  cluster_endpoint = var.cluster_endpoint

  # Versions
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version

  # Network
  network_bridge  = var.network_bridge
  network_gateway = var.network_gateway
  dns_servers     = var.dns_servers
  vip_ip          = var.vip_ip

  # Proxmox
  datastore_id   = var.datastore_id
  talos_image_id = var.talos_image_id

  # Nodes
  control_plane_nodes = var.control_plane_nodes
  worker_nodes        = var.worker_nodes

  # Tags
  tags = var.tags

  # Bootstrap
  deploy_bootstrap = var.deploy_bootstrap
}
