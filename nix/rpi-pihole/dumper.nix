{ pkgs, constants, ... }: {
  # Mount SanDisk USB drive
  fileSystems."/mnt/dump" = {
    device = "/dev/disk/by-label/dump";
    fsType = "ext4";
    options = [ "nofail" "noatime" ];
  };

  # Ensure mount point ownership
  systemd.tmpfiles.rules = [ "d /mnt/dump 0755 ${constants.username} users -" ];

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
      User = constants.username;
      ExecStart = "/var/lib/dumper/dumper /var/lib/dumper/config.json";
      Restart = "on-failure";
      RestartSec = "30s";
      StateDirectory = "dumper";
      StateDirectoryMode = "0755";

      # Hardening
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ReadWritePaths = [ "/mnt/dump" "/var/lib/dumper" ];
      PrivateTmp = true;
    };
  };

  # TrueNAS rsync aliases — reads REMOTE_PATH from config.json to target the right subdirectory
  programs.bash.shellAliases = {
    dump-to-truenas = builtins.concatStringsSep " " [
      "bash -c 'P=$(${pkgs.jq}/bin/jq -r .remote_path /var/lib/dumper/config.json);"
      # WAL/SHM are folded into Photos.sqlite by the dumper's wal_checkpoint(TRUNCATE);
      # never ship the sidecars or a stale copy corrupts the DB osxphotos reads.
      "rsync -rltvP --partial --omit-dir-times --no-perms --no-owner --no-group --exclude=lost+found --exclude=*.sqlite-wal --exclude=*.sqlite-shm"
      "/mnt/dump/\"$P\" truenas_admin@192.168.0.13:/mnt/scratch/dump/\"$P\"'"
    ];
    dump-from-truenas = builtins.concatStringsSep " " [
      "bash -c 'P=$(${pkgs.jq}/bin/jq -r .remote_path /var/lib/dumper/config.json);"
      "rsync -rltvP --partial --omit-dir-times --no-perms --no-owner --no-group --exclude=lost+found --exclude=*.sqlite-wal --exclude=*.sqlite-shm"
      "truenas_admin@192.168.0.13:/mnt/scratch/dump/\"$P\" /mnt/dump/\"$P\"'"
    ];
  };
}
