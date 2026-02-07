{ pkgs, lib, ... }: {
  # Enable Tailscale service
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";

    # Prevent Tailscale from overriding DNS settings
    extraUpFlags = [
      "--accept-dns=false"
    ];
  };

  # Firewall configuration
  networking.firewall = {
    # Allow Tailscale's UDP port
    allowedUDPPorts = [ 41641 ];

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
