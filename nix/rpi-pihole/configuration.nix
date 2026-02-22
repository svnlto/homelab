{ pkgs, constants, ... }: {
  imports = [ ./hardware.nix ./pihole.nix ./tailscale.nix ];

  # Network configuration
  networking = {
    hostName = "rpi-pihole";
    useDHCP = false;
    interfaces.eth0.ipv4.addresses = [{
      address = "192.168.0.53";
      prefixLength = 24;
    }];
    defaultGateway = "192.168.0.1";
    nameservers =
      [ "1.1.1.1" "8.8.8.8" ]; # Bootstrap DNS (before Pi-hole is running)

    firewall = {
      enable = true;
      allowedTCPPorts = [
        22 # SSH
        53 # DNS
        80 # Pi-hole web interface
        9100 # Prometheus node exporter
      ];
      allowedUDPPorts = [
        53 # DNS
        123 # NTP
      ];
    };
  };

  # SSH configuration
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
      PubkeyAuthentication = true;
    };
  };

  # User configuration
  users.users.${constants.username} = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ];
    openssh.authorizedKeys.keys = [
      # SSH public key from 1Password (same as Proxmox VMs)
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGAfz+KUctvSo0azvIQhHY2eBvKhT3pHRE0vpNtvpjMY"
    ];
  };

  # Enable sudo without password for wheel group
  security.sudo.wheelNeedsPassword = false;

  # Automatic system updates (NixOS-specific)
  system.autoUpgrade = {
    enable = true;
    allowReboot = false;
    dates = "daily";
    flake = "/etc/nixos";
  };

  # Automatic garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # Nix settings
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };

  # Reduce SD card wear — tmpfs for high-write paths
  fileSystems."/var/log" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [ "size=50M" "nodev" "nosuid" ];
  };
  fileSystems."/tmp" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [ "size=100M" "nodev" "nosuid" ];
  };

  # Cap journal size (persisted journals would go to tmpfs /var/log)
  services.journald.extraConfig = ''
    SystemMaxUse=30M
    RuntimeMaxUse=30M
  '';

  # NTP server for the network (K8s nodes use this to avoid DNS-dependent NTP)
  services.chrony = {
    enable = true;
    servers = [ "time.cloudflare.com" "time.google.com" ];
    extraConfig = ''
      # Allow NTP clients from all local subnets
      allow 192.168.0.0/24
      allow 10.0.0.0/8

      # Serve time even when not yet synced to upstream (prevents Talos boot timeouts)
      local stratum 10

      # Relaxed rate limiting for boot storms (all Talos nodes query at once)
      ratelimit interval 1 burst 16
    '';
  };

  # Timezone
  time.timeZone = constants.timezone;

  # System packages
  environment.systemPackages = with pkgs; [
    vim
    nano
    htop
    btop
    curl
    wget
    git
    dig
    nmap
    tcpdump
    iotop
    lsof
  ];

  # NixOS state version (for compatibility)
  system.stateVersion = "24.11";
}
