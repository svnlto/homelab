# ==============================================================================
# Tailscale ACL Policy + OAuth Client for K8s Operator
# ==============================================================================

resource "tailscale_acl" "this" {
  acl = jsonencode({
    // Tag owners — who can assign each tag to devices
    tagOwners = {
      for tag, owners in var.acl_tags : "tag:${tag}" => owners
    }

    // Grants — explicit per-path network access (deny-by-default)
    grants = [
      // --- Network access ---

      // Personal devices can reach each other
      { src = ["autogroup:member"], dst = ["autogroup:self"], ip = ["*"] },

      // Personal devices can reach all tagged infrastructure
      { src = ["autogroup:member"], dst = ["tag:k8s"], ip = ["*"] },
      { src = ["autogroup:member"], dst = ["tag:pihole"], ip = ["*"] },
      { src = ["autogroup:member"], dst = ["tag:dumper-src"], ip = ["*"] },
      { src = ["autogroup:member"], dst = ["tag:photo-relay"], ip = ["*"] },

      // K8s pods can reach Pi-hole (DNS) and photo-relay
      { src = ["tag:k8s"], dst = ["tag:pihole"], ip = ["*"] },
      { src = ["tag:k8s"], dst = ["tag:photo-relay"], ip = ["*"] },

      // Pi dumper can reach dumper-src Mac for rsync
      { src = ["tag:pihole"], dst = ["tag:dumper-src"], ip = ["*"] },

      // dumper-src Mac can reach photo-relay (relay path)
      { src = ["tag:dumper-src"], dst = ["tag:photo-relay"], ip = ["*"] },

      // --- Peer relay capabilities ---

      // K8s pods can use Pi-hole as a Tailscale peer relay
      {
        src = ["tag:k8s"]
        dst = ["tag:pihole"]
        app = { "tailscale.com/cap/relay" = [{}] }
      },
      // K8s pods, Pi, and dumper-src Mac can use photo-relay (Linode Singapore) as a peer relay
      {
        src = ["tag:k8s", "tag:dumper-src", "tag:pihole"]
        dst = ["tag:photo-relay"]
        app = { "tailscale.com/cap/relay" = [{}] }
      }
    ]

    // SSH access
    ssh = [
      // All members can SSH into their own devices (check mode = browser approval)
      {
        action = "check"
        src    = ["autogroup:member"]
        dst    = ["autogroup:self"]
        users  = ["autogroup:nonroot", "root"]
      },
      // Admins can SSH into K8s-tagged devices
      {
        action = "check"
        src    = ["autogroup:admin"]
        dst    = ["tag:k8s"]
        users  = ["autogroup:nonroot"]
      },
      // Admins can SSH into dumper-src-tagged devices
      {
        action = "check"
        src    = ["autogroup:admin"]
        dst    = ["tag:dumper-src"]
        users  = ["autogroup:nonroot", "root"]
      },
      // Pi dumper service can SSH into dumper-src Mac for rsync
      // Tagged device → tagged device requires action = "accept" (check not supported)
      {
        action = "accept"
        src    = ["tag:pihole"]
        dst    = ["tag:dumper-src"]
        users  = ["autogroup:nonroot", "root"]
      }
    ]

    // Node attributes
    nodeAttrs = [
      { target = [var.mullvad_exit_node_ip], attr = ["mullvad"] }
    ]

    // Auto-approve K8s operator subnet routes
    autoApprovers = {
      routes = {
        for cidr in var.k8s_auto_approved_routes : cidr => ["tag:k8s"]
      }
    }
  })
}

# OAuth client for the Tailscale Kubernetes operator.
# tag:k8s must exist in ACL before creating this client.
resource "tailscale_oauth_client" "k8s_operator" {
  description = "K8s operator - Tailscale ingress for Traefik"
  scopes      = ["devices:core", "auth_keys"]
  tags        = ["tag:k8s"]

  depends_on = [tailscale_acl.this]
}

output "k8s_oauth_client_id" {
  description = "OAuth client ID for the K8s Tailscale operator"
  value       = tailscale_oauth_client.k8s_operator.id
}

output "k8s_oauth_client_secret" {
  description = "OAuth client secret for the K8s Tailscale operator"
  value       = tailscale_oauth_client.k8s_operator.key
  sensitive   = true
}
