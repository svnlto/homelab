{ pkgs, constants, ... }: {
  imports = [ ./hardware.nix ./qdevice.nix ];

  # Network configuration
  networking = {
    hostName = "rpi-qdevice";
    useDHCP = false;
    interfaces.eth0.ipv4.addresses = [{
      address = constants.qdeviceIp;
      prefixLength = 24;
    }];
    defaultGateway = "192.168.0.1";
    nameservers = [ "192.168.0.53" ]; # Pi-hole

    firewall = {
      enable = true;
      allowedTCPPorts = [
        22 # SSH
        5403 # corosync-qnetd
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

  # Root SSH keys — required for `pvecm qdevice setup` from Proxmox nodes
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCkcXoXNQNdiK2sZMvabcod4WGzrRR5C5dyecKQkyNnKrMWOQdLfnvHWlAZHsTx6SlqDuj5BRSrIBIa+eezw+DBC3bvDBLNp2UW/suXBjaE6CSMk9f9DPTDmol0rA12DLTKqKpmQ1VmdTOl9WHhJHw6dwFIUGNI7rTnCURB6Kjr+QPLmFVH+Pu86grpn9PprCm+RUNaZQQC5J/V+jv9rRFB4tZTvzK+Qr0pW66TVmNIbmmh+vI48ynign9XslpDjITyy9Ti3J4vMa35QyTTEDUQHBR6pqH77xsOxz9hwZmzRYIkt0c6ZRdkArgP8udV9ddunpbQs+5sJgJ2mmJB1s5tm2oO8g9owA0S8T06HPPN7yCT120mrJ0tvxqZFwmKiXfyboy3kas4Pfh6cJyM+AuNJ6uy3l3lVGSreWK0wRD6RGY31Yn7NNlCEnbQQ3vfP4D+cLuzChe07qjYFztMRem6k86P3tnj6lywIsvlFXQjz6L7iC++9yvEiN/AXnt8YEiKj2eRcsmpvYPIf0ATBzHksvwBDxd8ZReB+/sErfbdrwvZD4sY48Q38wLQGXCdwyG/1hSbALWm5QkparA8YPrX2BXWYJkndJGUp1vuMUM96DJKJqqegUCYOi7Lmi1EmuFJdIBHYFW4/Aw2mD3AQEuXdHZNN/xLwgA9v6WtMSkW2w== root@din"
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDRCGJ1HRu9Xfx1jynBZcIKHDfJMCHA3p0b/nxNx8rzuVjj6IPkcybNykJDaxwW9k4VSBsZT0Noh82BidXUGl1m9E5Izc87lAuPipJVFxyeNOHV65KRsxV/0kcUeoiwwdwoeXrWz9n05MPtF7vHPyFOiJJKmkhN3WNQ62xM3wMG4llAWT1nMwbG/E64sZ8A8FRz+Tq2aD25o2qDnkixoH/o2PgqTtclB7bUkCzaM105RogZVUL3CPy+F6yGhuWT/uhMCyCFGLJGcyJq6Y6Enju5fpQ52XlIuF7qEzCchOyvifY/r4kBY21yOVZl3V0bW4zEOhftTKmziaSIecHqVn1i6KeRZ+X2P9kgEBs3tUxsUwOPUv7apu1RLOE1+ugka43fsEyS/Quy9CZGcUtigw/YMIPn/2hgsNUWA/j/KzKu6fgS/OVXfhrZ2cFYp+MPNYqePo5GLandimqNmiO2ybqrQ6Dw8cUk9EHvD+EFMjKVtF60tAHcREDuR7e53re+bbjV3vSIyuH9s3jWV3fg+Lhn8742pDdpYCNvPxs3zoJ4pO5IMBBya9Ef1Z4/NQnss/Cj0oJVhrEUGgLUcfHhNWxxsgHHU406D5o2Z+5usbC4qBISoBJ+2BajiR0+p3olYzqQHQSeh8p6A4g8yZV5iWDJn05UMNpb2bHvpAeGh+4uRw== root@grogu"
  ];

  # User configuration
  users.users.${constants.username} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
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

  # Timezone
  time.timeZone = constants.timezone;

  # System packages
  environment.systemPackages = with pkgs; [ vim htop curl git ];

  # NixOS state version (for compatibility)
  system.stateVersion = "24.11";
}
