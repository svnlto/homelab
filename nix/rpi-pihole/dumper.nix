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
  users.groups.dumper = { };

  # Ensure mount point ownership
  systemd.tmpfiles.rules = [ "d /mnt/dump 0755 dumper dumper -" ];

  # Dumper systemd service
  systemd.services.dumper = {
    description = "Photo sync from Mac to SanDisk via Tailscale";
    after = [ "network-online.target" "tailscaled.service" "mnt-dump.mount" ];
    wants = [ "network-online.target" "tailscaled.service" ];
    requires = [ "mnt-dump.mount" ];

    path = with pkgs; [ rsync openssh tailscale ];

    serviceConfig = {
      Type = "oneshot";
      User = "dumper";
      Group = "dumper";
      ExecStart = "/var/lib/dumper/dumper /var/lib/dumper/config.json";
      StateDirectory = "dumper";

      # Hardening
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [ "/mnt/dump" "/var/lib/dumper" ];
      PrivateTmp = true;
    };
  };

  # Dumper systemd timer
  systemd.timers.dumper = {
    description = "Hourly photo sync timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "hourly";
      RandomizedDelaySec = "5m";
      Persistent = true;
    };
  };

  # TrueNAS rsync aliases for svenlito user
  programs.bash.shellAliases = {
    dump-to-truenas =
      "rsync -avP --partial /mnt/dump/ svenlito@192.168.0.13:/mnt/scratch/dump/";
    dump-from-truenas =
      "rsync -avP --partial svenlito@192.168.0.13:/mnt/scratch/dump/ /mnt/dump/";
  };
}
