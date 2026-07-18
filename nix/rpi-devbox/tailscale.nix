_: {
  # Join the tailnet as a plain node (dev box, not a subnet router).
  # rpi-pihole already advertises the 192.168.0.0/24 route — a second
  # router for the same CIDR would conflict, so no --advertise-routes here.
  services.tailscale = {
    enable = true;

    # --accept-dns=false: keep Pi-hole as resolver, don't let Tailscale
    #   override /etc/resolv.conf
    # --ssh: allow Tailscale SSH into the box from the tailnet
    extraUpFlags = [
      "--accept-dns=false"
      "--ssh"
    ];
  };

  networking.firewall = {
    # 41641: Tailscale WireGuard
    allowedUDPPorts = [ 41641 ];

    # Required for Tailscale's NAT traversal
    checkReversePath = "loose";

    # Allow SSH from the Tailscale interface
    extraCommands = ''
      iptables -A INPUT -i tailscale0 -p tcp --dport 22 -j ACCEPT
    '';

    extraStopCommands = ''
      iptables -D INPUT -i tailscale0 -p tcp --dport 22 -j ACCEPT 2>/dev/null || true
    '';
  };

  systemd.services.tailscaled = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };
}
