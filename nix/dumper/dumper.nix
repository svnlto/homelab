{ pkgs, constants, ... }:

let
  dumpDir = "/mnt/dump";
  inherit (constants) truenasStorageIp;
  rsyncScript =
    pkgs.writeShellScript "rsync-photos" (builtins.readFile ./rsync-photos.sh);
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

    path = [
      pkgs.rsync
      pkgs.openssh
      pkgs.tailscale
      pkgs.gnugrep
      pkgs.findutils
      pkgs.coreutils
    ];

    serviceConfig = {
      Type = "exec";
      User = "dumper";
      Group = "media";
      EnvironmentFile = "/etc/dumper/rsync.env";
      ExecStart = rsyncScript;
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
