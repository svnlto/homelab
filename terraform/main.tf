terraform {
  required_version = ">= 1.5.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.93.0"
    }
    ansible = {
      source  = "ansible/ansible"
      version = "1.3.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.3"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "0.10.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.6.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.0.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.1.1"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_api_url
  api_token = "${var.proxmox_api_token_id}=${var.proxmox_api_token_secret}"
  insecure  = var.proxmox_tls_insecure

  ssh {
    agent = true
  }
}

provider "talos" {}

provider "kubernetes" {
  host = module.homelab_k8s.cluster_endpoint

  client_certificate = base64decode(
    yamldecode(module.homelab_k8s.kubeconfig_raw).users[0].user.client-certificate-data
  )
  client_key = base64decode(
    yamldecode(module.homelab_k8s.kubeconfig_raw).users[0].user.client-key-data
  )
  cluster_ca_certificate = base64decode(
    yamldecode(module.homelab_k8s.kubeconfig_raw).clusters[0].cluster.certificate-authority-data
  )
}

provider "helm" {
  kubernetes = {
    host = module.homelab_k8s.cluster_endpoint

    client_certificate = base64decode(
      yamldecode(module.homelab_k8s.kubeconfig_raw).users[0].user.client-certificate-data
    )
    client_key = base64decode(
      yamldecode(module.homelab_k8s.kubeconfig_raw).users[0].user.client-key-data
    )
    cluster_ca_certificate = base64decode(
      yamldecode(module.homelab_k8s.kubeconfig_raw).clusters[0].cluster.certificate-authority-data
    )
  }
}
