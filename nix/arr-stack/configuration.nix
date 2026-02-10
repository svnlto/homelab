{ pkgs, modulesPath, constants, ... }: {
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ./arr.nix ];

  # Boot loader (EFI — systemd-boot for UEFI/OVMF VM)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.growPartition = true;

  # Network configuration
  networking = {
    hostName = "arr-stack";
    useDHCP = false;
    interfaces.ens18.ipv4.addresses = [{
      address = "192.168.0.50";
      prefixLength = 24;
    }];
    defaultGateway = "192.168.0.1";
    nameservers = [ "192.168.0.53" ]; # Pi-hole DNS

    firewall = {
      enable = true;
      allowedTCPPorts = [
        22 # SSH
        5055 # Jellyseerr
        8096 # Jellyfin
        8701 # qBittorrent WebUI
        8080 # SABnzbd
        7878 # Radarr
        8989 # Sonarr
        8686 # Lidarr
        6767 # Bazarr
        9696 # Prowlarr
        8191 # FlareSolverr
        5030 # Slskd
        8090 # Glance
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

  # QEMU guest agent for Proxmox integration
  services.qemuGuest.enable = true;

  # Media user/group for NFSv4 idmapd name resolution
  # TrueNAS sends "media@localdomain" for file ownership on child ZFS datasets
  users.groups.media.gid = 1000;
  users.users.media = {
    isSystemUser = true;
    group = "media";
  };

  # User configuration
  users.users.${constants.username} = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" "media" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGAfz+KUctvSo0azvIQhHY2eBvKhT3pHRE0vpNtvpjMY"
    ];
  };

  # Enable sudo without password for wheel group
  security.sudo.wheelNeedsPassword = false;

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

  # Timezone
  time.timeZone = constants.timezone;

  # System packages
  environment.systemPackages = with pkgs; [ vim htop curl git ];

  # NixOS state version
  system.stateVersion = "25.11";
}
