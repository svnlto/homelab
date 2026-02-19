module "k8s_shared" {
  source = "../../../modules/talos-cluster"

  cluster_name     = var.cluster_name
  cluster_endpoint = var.cluster_endpoint

  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version

  network_bridge  = var.network_bridge
  network_gateway = var.network_gateway
  dns_servers     = var.dns_servers
  vip_ip          = var.vip_ip

  datastore_id   = var.datastore_id
  talos_image_id = var.talos_image_id

  control_plane_nodes = var.control_plane_nodes
  worker_nodes        = var.worker_nodes
  talos_schematic_id  = var.talos_schematic_id

  tags             = var.tags
  deploy_bootstrap = var.deploy_bootstrap

  truenas_api_url             = var.truenas_api_url
  truenas_api_key             = var.truenas_api_key
  truenas_nfs_dataset         = var.truenas_nfs_dataset
  truenas_nfs_fast_dataset    = var.truenas_nfs_fast_dataset
  truenas_nfs_scratch_dataset = var.truenas_nfs_scratch_dataset
  truenas_iscsi_portal        = var.truenas_iscsi_portal
  truenas_iscsi_dataset       = var.truenas_iscsi_dataset
  metallb_ip_range            = var.metallb_ip_range
  traefik_enabled             = var.traefik_enabled

  # Tailscale
  tailscale_enabled             = var.tailscale_enabled
  tailscale_oauth_client_id     = var.tailscale_oauth_client_id
  tailscale_oauth_client_secret = var.tailscale_oauth_client_secret
  tailscale_hostname            = var.tailscale_hostname

  # Traefik ACME
  traefik_acme_enabled  = var.traefik_acme_enabled
  traefik_acme_email    = var.traefik_acme_email
  traefik_acme_server   = var.traefik_acme_server
  cloudns_auth_id       = var.cloudns_auth_id
  cloudns_auth_password = var.cloudns_auth_password
}
