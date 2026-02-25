# ==============================================================================
# Linode Nanode (Singapore) — Tailscale peer relay for dumper photo sync
# ==============================================================================
#
# Replaces shared DERP Singapore relay with a dedicated Tailscale peer relay.
# Both the Mac (Asia) and the dumper pod (Europe) establish direct UDP
# connections to this node's public IP, bypassing DERP rate limits.

locals {
  label  = "photo-relay"
  region = "ap-south" # Singapore
  tags   = ["homelab", "tailscale", "photo-relay"]

  cloud_init = <<-USERDATA
    #!/bin/bash
    set -euo pipefail

    # Install Tailscale
    curl -fsSL https://tailscale.com/install.sh | sh

    # Enable IP forwarding (required for relay)
    cat > /etc/sysctl.d/99-tailscale-relay.conf <<'SYSCTL'
    net.ipv4.ip_forward = 1
    net.ipv6.conf.all.forwarding = 1
    SYSCTL
    sysctl --system

    # Start Tailscale and enable peer relay
    tailscale up \
      --authkey="${var.tailscale_auth_key}" \
      --hostname="photo-relay" \
      --advertise-tags="tag:photo-relay"
    tailscale set --relay-server-port=41642 \
      --relay-server-static-endpoints="$(curl -s http://169.254.169.254/v4/ip):41642"
  USERDATA
}

# SSH key for emergency access
resource "linode_sshkey" "homelab" {
  label   = "homelab-ed25519"
  ssh_key = var.ssh_public_key
}

# Nanode 1GB — $5/month
resource "linode_instance" "photo_relay" {
  label  = local.label
  region = local.region
  type   = "g6-nanode-1"
  image  = "linode/ubuntu24.04"
  tags   = local.tags

  authorized_keys = [linode_sshkey.homelab.ssh_key]

  metadata {
    user_data = base64encode(local.cloud_init)
  }

  lifecycle {
    ignore_changes = [metadata]
  }
}

# Firewall — SSH + Tailscale UDP
resource "linode_firewall" "photo_relay" {
  label = "${local.label}-fw"

  inbound {
    label    = "ssh"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "22"
    ipv4     = ["0.0.0.0/0"]
    ipv6     = ["::/0"]
  }

  inbound {
    label    = "tailscale-udp"
    action   = "ACCEPT"
    protocol = "UDP"
    ports    = "41641"
    ipv4     = ["0.0.0.0/0"]
    ipv6     = ["::/0"]
  }

  inbound {
    label    = "tailscale-relay"
    action   = "ACCEPT"
    protocol = "UDP"
    ports    = "41642"
    ipv4     = ["0.0.0.0/0"]
    ipv6     = ["::/0"]
  }

  inbound_policy  = "DROP"
  outbound_policy = "ACCEPT"

  linodes = [linode_instance.photo_relay.id]
}
