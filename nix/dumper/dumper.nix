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
    device = "${truenasStorageIp}:/mnt/scratch/dump";
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

    path = [ pkgs.rsync pkgs.openssh pkgs.tailscale pkgs.gnugrep ];

    serviceConfig = {
      Type = "oneshot";
      User = "dumper";
      Group = "media";
      EnvironmentFile = "/etc/dumper/rsync.env";
      ExecStart = pkgs.writeShellScript "rsync-photos" ''
        set -euo pipefail

        # Check if remote host is reachable via Tailscale (DERP relay is fine)
        PING_OUT=$(tailscale ping --timeout=30s --c=1 "''${REMOTE_HOST}" 2>&1 || true)
        if ! echo "$PING_OUT" | grep -q "pong"; then
          echo "Remote host ''${REMOTE_HOST} is not reachable, skipping sync"
          exit 0
        fi

        echo "Remote host reachable, starting sync"
        rsync -azP --partial \
          --rsync-path="sudo /usr/bin/rsync" \
          -e "ssh -i /var/lib/dumper/.ssh/id_ed25519 -o StrictHostKeyChecking=accept-new" \
          "''${REMOTE_USER}@''${REMOTE_HOST}:''${REMOTE_PATH}" \
          "${dumpDir}''${REMOTE_PATH}"
      '';
    };
  };

  # Check every 15 minutes, sync only when remote host is online
  systemd.timers.rsync-photos = {
    description = "Periodic rsync of photos from remote machine";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "15min";
      Persistent = true;
    };
  };
}
