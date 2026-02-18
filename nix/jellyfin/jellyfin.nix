{ pkgs, constants, ... }:

let
  dataDir = "/var/lib/jellyfin-data";
  nfsConfigDir = "/mnt/arr-config";
  mediaDir = "/mnt/media";
  composeDir = "/opt/stacks/jellyfin";

  inherit (constants) truenasStorageIp;

  puid = "1000";
  pgid = "1000";
  tz = constants.timezone;

  # Container image versions (pinned for reproducibility)
  images = {
    jellyfin = "jellyfin/jellyfin:10.11.4";
    jellyseerr = "fallenbagel/jellyseerr:2.7.3";
  };
in {
  # Intel Arc A310 GPU — VA-API hardware transcoding for Jellyfin
  hardware.graphics = {
    enable = true;
    extraPackages = [ pkgs.intel-media-driver ];
  };

  # Enable Docker
  virtualisation.docker.enable = true;

  # NFS client support
  boot.supportedFilesystems = [ "nfs" ];
  services.rpcbind.enable = true;

  # Enable NFSv4 idmapd so client can resolve string-based ownership
  # (TrueNAS sends "media@localdomain" for child ZFS datasets)
  boot.kernel.sysctl."fs.nfs.nfs4_disable_idmapping" = 0;

  # ---------------------------------------------------------------------------
  # NFS mounts from TrueNAS
  # ---------------------------------------------------------------------------

  # NFS config mount — kept for initial data migration, not used at runtime
  fileSystems.${nfsConfigDir} = {
    device = "${truenasStorageIp}:/mnt/bulk/arr-config";
    fsType = "nfs";
    options = [
      "nfsvers=4.2"
      "sec=sys"
      "rsize=131072"
      "wsize=131072"
      "hard"
      "nofail"
      "_netdev"
    ];
  };

  # Media — parent mount (NFS can't cross ZFS dataset boundaries,
  # so child datasets are mounted explicitly below)
  fileSystems.${mediaDir} = {
    device = "${truenasStorageIp}:/mnt/bulk/media";
    fsType = "nfs";
    options = [
      "nfsvers=4.2"
      "sec=sys"
      "rsize=131072"
      "wsize=131072"
      "hard"
      "nofail"
      "_netdev"
    ];
  };

  # Child ZFS datasets — separate NFS exports, must be mounted individually
  fileSystems."${mediaDir}/movies" = {
    device = "${truenasStorageIp}:/mnt/bulk/media/movies";
    fsType = "nfs";
    options = [
      "nfsvers=4.2"
      "sec=sys"
      "rsize=131072"
      "wsize=131072"
      "hard"
      "nofail"
      "_netdev"
    ];
  };

  fileSystems."${mediaDir}/tv" = {
    device = "${truenasStorageIp}:/mnt/bulk/media/tv";
    fsType = "nfs";
    options = [
      "nfsvers=4.2"
      "sec=sys"
      "rsize=131072"
      "wsize=131072"
      "hard"
      "nofail"
      "_netdev"
    ];
  };

  fileSystems."${mediaDir}/music" = {
    device = "${truenasStorageIp}:/mnt/bulk/media/music";
    fsType = "nfs";
    options = [
      "nfsvers=4.2"
      "sec=sys"
      "rsize=131072"
      "wsize=131072"
      "hard"
      "nofail"
      "_netdev"
    ];
  };

  fileSystems."${mediaDir}/books" = {
    device = "${truenasStorageIp}:/mnt/bulk/media/books";
    fsType = "nfs";
    options = [
      "nfsvers=4.2"
      "sec=sys"
      "rsize=131072"
      "wsize=131072"
      "hard"
      "nofail"
      "_netdev"
    ];
  };

  # Local directories (NFS dirs created by jellyfin-init service)
  systemd.tmpfiles.rules = [
    "d ${composeDir} 0755 root root -"
    "L+ ${composeDir}/docker-compose.yml - - - - /etc/jellyfin/docker-compose.yml"
  ];

  # ---------------------------------------------------------------------------
  # Docker Compose — Jellyfin media serving stack
  # ---------------------------------------------------------------------------
  environment.etc."jellyfin/docker-compose.yml".text = ''
    ---
    services:
      jellyfin:
        image: ${images.jellyfin}
        container_name: jellyfin
        environment:
          - PUID=${puid}
          - PGID=${pgid}
          - TZ=${tz}
        volumes:
          - ${dataDir}/jellyfin/config:/config
          - ${dataDir}/jellyfin/cache:/cache
          - ${mediaDir}:/data/media
        # Config on local disk — SQLite doesn't work on NFS
        ports:
          - 8096:8096
        devices:
          - /dev/dri:/dev/dri
        healthcheck:
          test: ["CMD-SHELL", "curl -f http://localhost:8096/health || exit 1"]
          interval: 30s
          timeout: 10s
          retries: 3
          start_period: 40s
        restart: unless-stopped

      jellyseerr:
        image: ${images.jellyseerr}
        container_name: jellyseerr
        environment:
          - PUID=${puid}
          - PGID=${pgid}
          - TZ=${tz}
        volumes:
          - ${dataDir}/jellyseerr/config:/app/config
        ports:
          - 5055:5055
        healthcheck:
          test: ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:5055/ || exit 1"]
          interval: 1m
          timeout: 10s
          retries: 3
          start_period: 30s
        restart: unless-stopped

  '';

  # ---------------------------------------------------------------------------
  # Environment template — copied to NFS on first boot, user edits with secrets
  # ---------------------------------------------------------------------------
  environment.etc."jellyfin/env.template".text = ''
    # Jellyfin Stack Environment Configuration
    # Edit this file with your actual credentials
    # This file persists in /var/lib/jellyfin-data — survives NixOS rebuilds

    TIMEZONE=${tz}

    # Jellyfin
    JELLYFIN_API_KEY=

  '';

  # ---------------------------------------------------------------------------
  # Systemd services
  # ---------------------------------------------------------------------------

  # Initialize local directories and migrate data from NFS on first boot
  systemd.services.jellyfin-init = {
    description = "Initialize Jellyfin stack directories and configs";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    unitConfig.RequiresMountsFor = "${nfsConfigDir} ${mediaDir}";

    path = [ pkgs.coreutils pkgs.rsync ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "jellyfin-init" ''
        set -euo pipefail

        # Create local directories
        mkdir -p ${dataDir}/jellyfin/config
        mkdir -p ${dataDir}/jellyfin/cache
        mkdir -p ${dataDir}/jellyseerr/config
        # Migrate from NFS to local storage (one-time)
        if [ ! -f ${dataDir}/.migrated ]; then
          echo "Migrating Jellyfin data from NFS to local storage..."

          if [ -d ${nfsConfigDir}/jellyfin/config ] && [ -f ${nfsConfigDir}/jellyfin/config/data/jellyfin.db ]; then
            rsync -a ${nfsConfigDir}/jellyfin/config/ ${dataDir}/jellyfin/config/
            echo "Migrated jellyfin config"
          fi

          if [ -d ${nfsConfigDir}/jellyfin/cache ]; then
            rsync -a ${nfsConfigDir}/jellyfin/cache/ ${dataDir}/jellyfin/cache/
            echo "Migrated jellyfin cache"
          fi

          if [ -d ${nfsConfigDir}/jellyseerr ]; then
            rsync -a ${nfsConfigDir}/jellyseerr/ ${dataDir}/jellyseerr/config/
            echo "Migrated jellyseerr config"
          fi

          touch ${dataDir}/.migrated
          echo "Migration complete"
        fi

        # Copy .env template if not present
        if [ ! -f ${dataDir}/jellyfin-env ]; then
          if [ -f ${nfsConfigDir}/jellyfin-env ]; then
            cp ${nfsConfigDir}/jellyfin-env ${dataDir}/jellyfin-env
          else
            cp /etc/jellyfin/env.template ${dataDir}/jellyfin-env
            echo "Created ${dataDir}/jellyfin-env from template — edit with your secrets"
          fi
        fi

        # Symlink .env to compose directory
        ln -sf ${dataDir}/jellyfin-env ${composeDir}/.env

        echo "Jellyfin stack initialization complete"
      '';
    };
  };

  # Jellyfin stack docker-compose service
  systemd.services.jellyfin-stack = {
    description = "Jellyfin Media Stack";
    after =
      [ "docker.service" "network-online.target" "jellyfin-init.service" ];
    wants = [ "network-online.target" ];
    requires = [ "docker.service" "jellyfin-init.service" ];
    wantedBy = [ "multi-user.target" ];

    unitConfig.RequiresMountsFor = mediaDir;

    path = [ pkgs.docker pkgs.docker-compose pkgs.coreutils ];

    serviceConfig = {
      Type = "simple";
      TimeoutStartSec = "600";
      WorkingDirectory = composeDir;
      ExecStartPre = "${pkgs.docker-compose}/bin/docker-compose up -d";
      ExecStart = pkgs.writeShellScript "jellyfin-stack-monitor" ''
        set -euo pipefail

        # Monitor loop — exits non-zero if jellyfin is down,
        # which triggers systemd Restart=on-failure
        while true; do
          sleep 60

          # Check that jellyfin is running
          if ! docker inspect --format='{{.State.Running}}' jellyfin 2>/dev/null | grep -q true; then
            echo "jellyfin is not running, restarting stack..."
            docker-compose up -d
            sleep 30
          fi
        done
      '';
      ExecStop = "${pkgs.docker-compose}/bin/docker-compose down";
      Restart = "on-failure";
      RestartSec = "30s";
    };
  };

}
