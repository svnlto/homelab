{ pkgs, ... }: {
  # Mount SanDisk USB drive
  fileSystems."/mnt/dump" = {
    device = "/dev/disk/by-label/dump";
    fsType = "ext4";
    options = [ "nofail" "noatime" ];
  };

  # Dumper system user
  users.users.dumper = {
    isSystemUser = true;
    group = "dumper";
    home = "/var/lib/dumper";
  };
  users.groups.dumper.members = [ "svenlito" ];

  # Ensure mount point ownership (group-writable for svenlito rsync aliases)
  systemd.tmpfiles.rules = [ "d /mnt/dump 0775 dumper dumper -" ];

  # Dumper systemd service (long-running, loops internally)
  systemd.services.dumper = {
    description = "Photo sync from Mac to SanDisk via Tailscale";
    after = [ "network-online.target" "tailscaled.service" "mnt-dump.mount" ];
    wants = [ "network-online.target" "tailscaled.service" ];
    requires = [ "mnt-dump.mount" ];
    wantedBy = [ "multi-user.target" ];

    path = with pkgs; [ rsync openssh tailscale ];

    serviceConfig = {
      Type = "simple";
      User = "dumper";
      Group = "dumper";
      ExecStart = "/var/lib/dumper/dumper /var/lib/dumper/config.json";
      Restart = "on-failure";
      RestartSec = "30s";
      StateDirectory = "dumper";

      # Hardening
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [ "/mnt/dump" "/var/lib/dumper" ];
      PrivateTmp = true;
    };
  };

  # TrueNAS rsync aliases — reads REMOTE_PATH from config.json to target the right subdirectory
  programs.bash.shellAliases = {
    dump-to-truenas = builtins.concatStringsSep " " [
      "bash -c 'P=$(${pkgs.jq}/bin/jq -r .remote_path /var/lib/dumper/config.json);"
      "rsync -avP --partial --exclude=lost+found"
      "/mnt/dump/\"$P\" truenas_admin@192.168.0.13:/mnt/fast/dump/\"$P\"'"
    ];
    dump-from-truenas = builtins.concatStringsSep " " [
      "bash -c 'P=$(${pkgs.jq}/bin/jq -r .remote_path /var/lib/dumper/config.json);"
      "rsync -avP --partial --exclude=lost+found"
      "truenas_admin@192.168.0.13:/mnt/fast/dump/\"$P\" /mnt/dump/\"$P\"'"
    ];
  };
}
