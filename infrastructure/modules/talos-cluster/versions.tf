terraform {
  required_version = ">= 1.14.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.111.1"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "0.10.1"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.7.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.2.1"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = "2.4.1"
    }
  }
}
