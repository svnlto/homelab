{ pkgs, constants, ... }:
let
  truenasHost = "truenas_admin@192.168.0.13";
  truenasBase = "/mnt/scratch/dump";

  rsyncArgs = builtins.concatStringsSep " " (map (f: "'" + f + "'") rsyncFlags);

  rsyncFlags = [
    "-rlt"
    "--info=progress2"
    # Never leave a half-written file at the destination path: an interrupted
    # --partial transfer once shipped a truncated Photos.sqlite that osxphotos
    # then rejected as "database disk image is malformed" for 19 days.
    "--partial-dir=.rsync-partial"
    "--omit-dir-times"
    "--no-perms"
    "--no-owner"
    "--no-group"
    "--exclude=lost+found"
    # WAL/SHM are folded into Photos.sqlite by the dumper's wal_checkpoint(TRUNCATE);
    # never ship the sidecars or a stale copy corrupts the DB osxphotos reads.
    "--exclude=*.sqlite-wal"
    "--exclude=*.sqlite-shm"
  ];

  # A SQLite header declares its page count; a truncated file holds fewer pages
  # than it claims. Cheap to check and catches exactly the torn-transfer case.
  pageCheckBody = ''
    f=$1
    if [ ! -f "$f" ]; then
      echo "FATAL: $f does not exist" >&2
      exit 1
    fi
    sz=$(stat -c %s "$f")
    hdr=$(dd if="$f" bs=32 count=1 2>/dev/null | od -An -tx1 | tr -d ' \n')
    ps=$((16#''${hdr:32:4}))
    if [ "$ps" -eq 1 ]; then
      ps=65536
    fi
    pc=$((16#''${hdr:56:8}))
    on_disk=$((sz / ps))
    if [ "$on_disk" -ne "$pc" ]; then
      echo "FATAL: $f is truncated — header declares $pc pages, file holds $on_disk" >&2
      exit 1
    fi
    echo "ok: $f — $pc pages, consistent"
  '';

  sqlite-pagecheck = pkgs.writeShellApplication {
    name = "sqlite-pagecheck";
    runtimeInputs = [ pkgs.coreutils ];
    text = pageCheckBody;
  };

  dump-to-truenas = pkgs.writeShellApplication {
    name = "dump-to-truenas";
    runtimeInputs = [
      pkgs.rsync
      pkgs.jq
      pkgs.openssh
      pkgs.coreutils
      sqlite-pagecheck
    ];
    text = ''
      P=$(jq -r .remote_path /var/lib/dumper/config.json)

      echo "==> verifying local database"
      sqlite-pagecheck "/mnt/dump/$P/database/Photos.sqlite"

      echo "==> syncing to TrueNAS"
      rsync ${rsyncArgs} \
        "/mnt/dump/$P" "${truenasHost}:${truenasBase}/$P"

      echo "==> verifying database on TrueNAS"
      ssh ${truenasHost} bash -s -- "${truenasBase}/$P/database/Photos.sqlite" <<'PAGECHECK'
      ${pageCheckBody}
      PAGECHECK

      echo "==> sync verified"
    '';
  };

  dump-from-truenas = pkgs.writeShellApplication {
    name = "dump-from-truenas";
    runtimeInputs = [
      pkgs.rsync
      pkgs.jq
      pkgs.openssh
      pkgs.coreutils
      sqlite-pagecheck
    ];
    text = ''
      P=$(jq -r .remote_path /var/lib/dumper/config.json)

      echo "==> syncing from TrueNAS"
      rsync ${rsyncArgs} \
        "${truenasHost}:${truenasBase}/$P" "/mnt/dump/$P"

      echo "==> verifying local database"
      sqlite-pagecheck "/mnt/dump/$P/database/Photos.sqlite"

      echo "==> sync verified"
    '';
  };
in
{
  # Mount SanDisk USB drive
  fileSystems."/mnt/dump" = {
    device = "/dev/disk/by-label/dump";
    fsType = "ext4";
    options = [
      "nofail"
      "noatime"
    ];
  };

  # Ensure mount point ownership
  systemd.tmpfiles.rules = [ "d /mnt/dump 0755 ${constants.username} users -" ];

  environment.systemPackages = [
    sqlite-pagecheck
    dump-to-truenas
    dump-from-truenas
  ];

  # Dumper systemd service (long-running, loops internally)
  systemd.services.dumper = {
    description = "Photo sync from Mac to SanDisk via Tailscale";
    after = [
      "network-online.target"
      "tailscaled.service"
      "mnt-dump.mount"
    ];
    wants = [
      "network-online.target"
      "tailscaled.service"
    ];
    requires = [ "mnt-dump.mount" ];
    wantedBy = [ "multi-user.target" ];

    path = with pkgs; [
      rsync
      openssh
      tailscale
    ];

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
      ReadWritePaths = [
        "/mnt/dump"
        "/var/lib/dumper"
      ];
      PrivateTmp = true;
    };
  };
}
