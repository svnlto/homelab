terraform {
  required_version = ">= 1.14.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.101.1"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.4"
    }
  }
}
