{ pkgs, modulesPath, constants, ... }: {
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ./dumper.nix ];

  # Boot loader (EFI — systemd-boot for UEFI/OVMF VM)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.growPartition = true;

  # Network configuration
  networking = {
    hostName = "dumper";
    useDHCP = false;
    interfaces.ens18.ipv4.addresses = [{
      address = constants.dumperIp;
      prefixLength = 24;
    }];
    interfaces.ens19.ipv4.addresses = [{
      address = "10.10.10.52";
      prefixLength = 24;
    }];
    defaultGateway = "192.168.0.1";
    nameservers = [ "192.168.0.53" ]; # Pi-hole DNS

    firewall = {
      enable = true;
      allowedTCPPorts = [
        22 # SSH
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

  # User configuration
  users.users.${constants.username} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
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
  environment.systemPackages = with pkgs; [ vim htop curl rsync ];

  # NixOS state version
  system.stateVersion = "25.11";
}
