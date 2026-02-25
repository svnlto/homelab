# ==============================================================================
# Tailscale ACL Policy + OAuth Client for K8s Operator
# ==============================================================================

resource "tailscale_acl" "this" {
  acl = jsonencode({
    // Tag owners — who can assign each tag to devices
    tagOwners = {
      for tag, owners in var.acl_tags : "tag:${tag}" => owners
    }

    // Grants — default: allow all connections
    grants = [
      { src = ["*"], dst = ["*"], ip = ["*"] },
      // Allow K8s pods to use Pi-hole as a Tailscale peer relay
      {
        src = ["tag:k8s"]
        dst = ["tag:pihole"]
        app = { "tailscale.com/cap/relay" = [{}] }
      },
      // Allow K8s pods and dumper-src Mac to use photo-relay (Linode Singapore) as a peer relay
      {
        src = ["tag:k8s", "tag:dumper-src"]
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
      // K8s dumper CronJob pods can SSH into dumper-src for rsync
      // Tagged device → tagged device requires action = "accept" (check not supported)
      {
        action = "accept"
        src    = ["tag:k8s"]
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
