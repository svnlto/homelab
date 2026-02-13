{ pkgs, constants, ... }:

let
  dumpDir = "/mnt/dump";
  inherit (constants) truenasStorageIp;
in {
  # Tailscale VPN — persistent authentication, no 24h reauth
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
  };

  # NFS client support
  boot.supportedFilesystems = [ "nfs" ];
  services.rpcbind.enable = true;

  # ---------------------------------------------------------------------------
  # NFS mount from TrueNAS (scratch pool over storage VLAN)
  # ---------------------------------------------------------------------------
  fileSystems.${dumpDir} = {
    device = "${truenasStorageIp}:/mnt/scratch/immich-migration/dump";
    fsType = "nfs";
    options = [
      "nfsvers=4.2"
      "sec=sys"
      "rsize=131072"
      "wsize=131072"
      "hard"
      "_netdev"
    ];
  };

  # ---------------------------------------------------------------------------
  # Rsync service — pulls photos from remote machine over Tailscale
  # ---------------------------------------------------------------------------
  # Secrets in /etc/dumper/rsync.env (pushed via `just dumper-secrets`):
  #   REMOTE_HOST=100.x.x.x
  #   REMOTE_PATH=/path/to/photos/

  systemd.services.rsync-photos = {
    description = "Rsync photos from remote machine via Tailscale";
    after = [ "network-online.target" "tailscaled.service" ];
    wants = [ "network-online.target" ];
    requires = [ "tailscaled.service" ];

    unitConfig.RequiresMountsFor = dumpDir;

    path = [ pkgs.rsync pkgs.openssh ];

    serviceConfig = {
      Type = "oneshot";
      EnvironmentFile = "/etc/dumper/rsync.env";
      ExecStart = pkgs.writeShellScript "rsync-photos" ''
        set -euo pipefail
        rsync -azP --partial \
          --rsync-path="sudo /usr/bin/rsync" \
          -e "ssh -o StrictHostKeyChecking=accept-new" \
          "''${REMOTE_HOST}:''${REMOTE_PATH}" \
          ${dumpDir}/
      '';
    };
  };

  # Daily timer for rsync
  systemd.timers.rsync-photos = {
    description = "Daily rsync of photos from remote machine";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
  };
}
