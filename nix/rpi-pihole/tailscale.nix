_: {
  # Enable Tailscale service
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";

    # Prevent Tailscale from overriding DNS settings
    # --advertise-routes: subnet router for VLAN 20 (LAN)
    extraUpFlags = [ "--accept-dns=false" "--advertise-routes=192.168.0.0/24" ];

    # Peer relay uses `tailscale set`, not `tailscale up`
    extraSetFlags = [ "--relay-server-port=41642" ];
  };

  # Firewall configuration
  networking.firewall = {
    # Allow Tailscale's UDP port
    # 41641: Tailscale WireGuard, 41642: Tailscale peer relay
    allowedUDPPorts = [ 41641 41642 ];

    # Required for Tailscale's NAT traversal
    checkReversePath = "loose";

    # Allow DNS queries from Tailscale interface
    extraCommands = ''
      iptables -A INPUT -i tailscale0 -p tcp --dport 53 -j ACCEPT
      iptables -A INPUT -i tailscale0 -p udp --dport 53 -j ACCEPT
      iptables -A INPUT -i tailscale0 -p tcp --dport 80 -j ACCEPT
      iptables -A INPUT -i tailscale0 -p tcp --dport 22 -j ACCEPT
    '';

    # Cleanup rules when firewall stops
    extraStopCommands = ''
      iptables -D INPUT -i tailscale0 -p tcp --dport 53 -j ACCEPT 2>/dev/null || true
      iptables -D INPUT -i tailscale0 -p udp --dport 53 -j ACCEPT 2>/dev/null || true
      iptables -D INPUT -i tailscale0 -p tcp --dport 80 -j ACCEPT 2>/dev/null || true
      iptables -D INPUT -i tailscale0 -p tcp --dport 22 -j ACCEPT 2>/dev/null || true
    '';
  };

  # Ensure Tailscale starts after network
  systemd.services.tailscaled = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };
}
