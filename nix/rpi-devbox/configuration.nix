{ pkgs, constants, ... }: {
  imports = [
    ./hardware.nix
    ./tailscale.nix
  ];

  # Network configuration
  networking = {
    hostName = "rpi-devbox";
    useDHCP = false;
    interfaces.eth0.ipv4.addresses = [
      {
        address = constants.devboxIp;
        prefixLength = 24;
      }
    ];
    defaultGateway = "192.168.0.1";
    nameservers = [ "192.168.0.53" ]; # Pi-hole

    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 ];
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
    extraGroups = [
      "wheel"
      "docker"
    ];
    openssh.authorizedKeys.keys = [
      # SSH public key from 1Password (same as Proxmox VMs)
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGAfz+KUctvSo0azvIQhHY2eBvKhT3pHRE0vpNtvpjMY"
    ];
  };

  # Enable sudo without password for wheel group
  security.sudo.wheelNeedsPassword = false;

  # Container runtime for development workloads
  virtualisation.docker = {
    enable = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  # Automatic garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # Nix settings
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
  };

  # Reduce SD card wear — tmpfs for high-write paths
  fileSystems."/var/log" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [
      "size=50M"
      "nodev"
      "nosuid"
    ];
  };
  fileSystems."/tmp" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [
      "size=100M"
      "nodev"
      "nosuid"
    ];
  };

  # Cap journal size (persisted journals would go to tmpfs /var/log)
  services.journald.extraConfig = ''
    SystemMaxUse=30M
    RuntimeMaxUse=30M
  '';

  # Timezone
  time.timeZone = constants.timezone;

  # System packages
  environment.systemPackages = with pkgs; [
    vim
    htop
    curl
    git
    docker-compose
  ];

  # NixOS state version (for compatibility)
  system.stateVersion = "24.11";
}
