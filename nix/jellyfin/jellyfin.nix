{ pkgs, constants, ... }:

let
  dataDir = "/mnt/arr-config";
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
    jellyfinAutoCollections =
      "ghcr.io/ghomashudson/jellyfin-auto-collections:5726c4c1ba8c13662404df2c079dc3d9fb7b9d67";
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

  # Config data — regular mount (required for service startup)
  fileSystems.${dataDir} = {
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
          - ${dataDir}/jellyseerr:/app/config
        ports:
          - 5055:5055
        healthcheck:
          test: ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:5055/ || exit 1"]
          interval: 1m
          timeout: 10s
          retries: 3
          start_period: 30s
        restart: unless-stopped

      jellyfin-auto-collections:
        image: ${images.jellyfinAutoCollections}
        container_name: jellyfin-auto-collections
        environment:
          - TZ=${tz}
          - JELLYFIN_SERVER_URL=http://jellyfin:8096
          - JELLYFIN_API_KEY=''${JELLYFIN_API_KEY}
          - JELLYFIN_USER_ID=''${JELLYFIN_USER_ID}
          - JELLYSEERR_EMAIL=''${JELLYSEERR_EMAIL}
          - JELLYSEERR_PASSWORD=''${JELLYSEERR_PASSWORD}
          - CRONTAB=0 6 * * *
        volumes:
          - ${dataDir}/jellyfin-auto-collections:/app/config
        depends_on:
          jellyfin:
            condition: service_healthy
        restart: unless-stopped
  '';

  # ---------------------------------------------------------------------------
  # Environment template — copied to NFS on first boot, user edits with secrets
  # ---------------------------------------------------------------------------
  environment.etc."jellyfin/env.template".text = ''
    # Jellyfin Stack Environment Configuration
    # Edit this file with your actual credentials
    # This file persists on TrueNAS NFS — survives NixOS rebuilds

    TIMEZONE=${tz}

    # Jellyfin
    JELLYFIN_API_KEY=
    JELLYFIN_USER_ID=

    # Jellyseerr
    JELLYSEERR_EMAIL=
    JELLYSEERR_PASSWORD=

  '';

  # ---------------------------------------------------------------------------
  # Systemd services
  # ---------------------------------------------------------------------------

  # Initialize NFS directories and seed configs on first boot
  systemd.services.jellyfin-init = {
    description = "Initialize Jellyfin stack directories and configs";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    unitConfig.RequiresMountsFor = "${dataDir} ${mediaDir}";

    path = [ pkgs.coreutils ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "jellyfin-init" ''
        set -euo pipefail

        # Create service directories on NFS
        mkdir -p ${dataDir}/jellyfin/config
        mkdir -p ${dataDir}/jellyfin/cache
        mkdir -p ${dataDir}/jellyseerr
        mkdir -p ${dataDir}/jellyfin-auto-collections

        # Copy .env template if not present
        if [ ! -f ${dataDir}/jellyfin-env ]; then
          cp /etc/jellyfin/env.template ${dataDir}/jellyfin-env
          echo "Created ${dataDir}/jellyfin-env from template — edit with your secrets"
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

    unitConfig.RequiresMountsFor = "${dataDir} ${mediaDir}";

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
