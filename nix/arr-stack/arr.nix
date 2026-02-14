{ pkgs, constants, ... }:

let
  dataDir = "/mnt/arr-config";
  mediaDir = "/mnt/media";
  scratchDir = "/mnt/scratch";
  composeDir = "/opt/stacks/arr";

  inherit (constants) truenasStorageIp;

  puid = "1000";
  pgid = "1000";
  tz = constants.timezone;

  # Container image versions (pinned for reproducibility)
  images = {
    gluetun = "qmcgaw/gluetun:v3.41.1";
    qbittorrent = "lscr.io/linuxserver/qbittorrent:5.1.4-r1-ls431";
    sabnzbd = "lscr.io/linuxserver/sabnzbd:4.5.1-ls223";
    radarr = "lscr.io/linuxserver/radarr:6.0.4.10291-ls288";
    sonarr = "lscr.io/linuxserver/sonarr:4.0.16.2944-ls299";
    lidarr = "ghcr.io/hotio/lidarr:pr-plugins-3.0.0.4856";
    bazarr = "lscr.io/linuxserver/bazarr:v1.5.5-ls336";
    slskd = "slskd/slskd:0.24.3";
    prowlarr = "lscr.io/linuxserver/prowlarr:2.3.0.5236-ls133";
    flaresolverr = "ghcr.io/flaresolverr/flaresolverr:v3.4.6";
    recyclarr = "ghcr.io/recyclarr/recyclarr:7.5.2";
    buildarr = "callum027/buildarr:0.7.8";
    glance = "glanceapp/glance:v0.8.4";
  };
in {
  # Enable Docker
  virtualisation.docker.enable = true;

  # NFS client support
  boot.supportedFilesystems = [ "nfs" ];
  services.rpcbind.enable = true;

  # Enable NFSv4 idmapd so client can resolve string-based ownership
  # (TrueNAS sends "media@localdomain" for child ZFS datasets)
  boot.kernel.sysctl."fs.nfs.nfs4_disable_idmapping" = 0;

  # NixOS doesn't create /etc/timezone — needed by glance container bind mount
  environment.etc."timezone".text = ''
    ${tz}
  '';

  # ---------------------------------------------------------------------------
  # NFS mounts from TrueNAS
  # ---------------------------------------------------------------------------

  # Config data — regular mount (required for service startup)
  # TODO: Move to fast/arr-config once MD1220 hardware arrives
  fileSystems.${dataDir} = {
    device = "${truenasStorageIp}:/mnt/bulk/arr-config";
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
      "_netdev"
    ];
  };

  # Scratch — persistent mount (active/incomplete downloads)
  fileSystems.${scratchDir} = {
    device = "${truenasStorageIp}:/mnt/scratch/downloads/incomplete";
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

  # Local directories (NFS dirs created by arr-init service)
  systemd.tmpfiles.rules = [
    "d ${composeDir} 0755 root root -"
    "L+ ${composeDir}/docker-compose.yml - - - - /etc/arr/docker-compose.yml"
  ];

  # ---------------------------------------------------------------------------
  # Docker Compose — arr media acquisition stack
  # ---------------------------------------------------------------------------
  environment.etc."arr/docker-compose.yml".text = ''
    ---
    services:
      gluetun:
        image: ${images.gluetun}
        container_name: gluetun
        cap_add:
          - NET_ADMIN
        devices:
          - /dev/net/tun:/dev/net/tun
        ports:
          - 8701:8701
          - 8080:8080
          - 7878:7878
          - 8989:8989
          - 8686:8686
          - 6767:6767
          - 9696:9696
          - 8191:8191
          - 5030:5030
        environment:
          - VPN_SERVICE_PROVIDER=protonvpn
          - VPN_TYPE=wireguard
          - WIREGUARD_PRIVATE_KEY=''${WIREGUARD_PRIVATE_KEY}
          - WIREGUARD_ADDRESSES=''${WIREGUARD_ADDRESSES}
          - SERVER_COUNTRIES=Sweden
          - VPN_PORT_FORWARDING=on
          - VPN_PORT_FORWARDING_PROVIDER=protonvpn
          - UPDATER_PERIOD=24h
          - HEALTH_VPN_DURATION_INITIAL=30s
          - HEALTH_VPN_DURATION_ADDITION=30s
        volumes:
          - ${dataDir}/gluetun:/gluetun
        healthcheck:
          test: ["CMD-SHELL", "wget --no-verbose --tries=1 -O /dev/null -T 3 https://www.google.com || exit 1"]
          interval: 1m
          timeout: 10s
          retries: 3
          start_period: 30s
        restart: unless-stopped

      qbittorrent:
        image: ${images.qbittorrent}
        container_name: qbittorrent
        network_mode: service:gluetun
        environment:
          - PUID=${puid}
          - PGID=${pgid}
          - TZ=${tz}
          - WEBUI_PORT=8701
        volumes:
          - ${dataDir}/qbittorrent:/config
          - ${mediaDir}:/data/media
          - ${scratchDir}:/data-scratch
        depends_on:
          gluetun:
            condition: service_healthy
        restart: unless-stopped

      sabnzbd:
        image: ${images.sabnzbd}
        container_name: sabnzbd
        network_mode: service:gluetun
        environment:
          - PUID=${puid}
          - PGID=${pgid}
          - TZ=${tz}
        volumes:
          - ${dataDir}/sabnzbd:/config
          - ${mediaDir}:/data/media
          - ${scratchDir}:/data-scratch
        depends_on:
          gluetun:
            condition: service_healthy
        restart: unless-stopped

      radarr:
        image: ${images.radarr}
        container_name: radarr
        network_mode: service:gluetun
        environment:
          - PUID=${puid}
          - PGID=${pgid}
          - TZ=${tz}
        volumes:
          - ${dataDir}/radarr:/config
          - ${mediaDir}:/data/media
        depends_on:
          gluetun:
            condition: service_healthy
        restart: unless-stopped

      sonarr:
        image: ${images.sonarr}
        container_name: sonarr
        network_mode: service:gluetun
        environment:
          - PUID=${puid}
          - PGID=${pgid}
          - TZ=${tz}
        volumes:
          - ${dataDir}/sonarr:/config
          - ${mediaDir}:/data/media
        depends_on:
          gluetun:
            condition: service_healthy
        restart: unless-stopped

      lidarr:
        image: ${images.lidarr}
        container_name: lidarr
        network_mode: service:gluetun
        environment:
          - PUID=${puid}
          - PGID=${pgid}
          - TZ=${tz}
        volumes:
          - ${dataDir}/lidarr:/config
          - ${mediaDir}:/data/media
        depends_on:
          gluetun:
            condition: service_healthy
        restart: unless-stopped

      bazarr:
        image: ${images.bazarr}
        container_name: bazarr
        network_mode: service:gluetun
        environment:
          - PUID=${puid}
          - PGID=${pgid}
          - TZ=${tz}
        volumes:
          - ${dataDir}/bazarr:/config
          - ${mediaDir}:/data/media
        depends_on:
          - gluetun
        restart: unless-stopped

      slskd:
        image: ${images.slskd}
        container_name: slskd
        network_mode: service:gluetun
        environment:
          - PUID=${puid}
          - PGID=${pgid}
          - TZ=${tz}
        volumes:
          - ${dataDir}/slskd:/app
          - ${mediaDir}/downloads/soulseek:/downloads
          - ${mediaDir}/music:/music:ro
        depends_on:
          - gluetun
        restart: unless-stopped
        healthcheck:
          test: ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:5030/ || exit 1"]
          interval: 2m
          timeout: 10s
          retries: 3
          start_period: 30s

      prowlarr:
        image: ${images.prowlarr}
        container_name: prowlarr
        network_mode: service:gluetun
        environment:
          - PUID=${puid}
          - PGID=${pgid}
          - TZ=${tz}
        volumes:
          - ${dataDir}/prowlarr:/config
        depends_on:
          gluetun:
            condition: service_healthy
        restart: unless-stopped

      flaresolverr:
        image: ${images.flaresolverr}
        container_name: flaresolverr
        network_mode: service:gluetun
        environment:
          - LOG_LEVEL=info
          - TZ=${tz}
        depends_on:
          - gluetun
        restart: unless-stopped

      recyclarr:
        image: ${images.recyclarr}
        container_name: recyclarr
        network_mode: service:gluetun
        environment:
          - TZ=${tz}
          - RADARR_API_KEY=''${RADARR_API_KEY}
          - SONARR_API_KEY=''${SONARR_API_KEY}
        volumes:
          - ${dataDir}/recyclarr:/config
          - /etc/arr/recyclarr.yml:/config/recyclarr.yml:ro
        depends_on:
          - gluetun
        restart: unless-stopped

      buildarr:
        image: ${images.buildarr}
        container_name: buildarr
        network_mode: service:gluetun
        entrypoint: ["/config/entrypoint.sh", "daemon"]
        environment:
          - TZ=${tz}
          - RADARR_API_KEY=''${RADARR_API_KEY}
          - SONARR_API_KEY=''${SONARR_API_KEY}
          - PROWLARR_API_KEY=''${PROWLARR_API_KEY}
          - LIDARR_API_KEY=''${LIDARR_API_KEY}
          - BAZARR_API_KEY=''${BAZARR_API_KEY}
        volumes:
          - ${dataDir}/buildarr:/config
          - /etc/arr/buildarr.yml:/config/buildarr.yml.tmpl:ro
        depends_on:
          - gluetun
        restart: unless-stopped

      glance:
        image: ${images.glance}
        container_name: glance
        environment:
          - TZ=${tz}
        volumes:
          - ${dataDir}/glance:/app/config
          - /etc/timezone:/etc/timezone:ro
          - /etc/localtime:/etc/localtime:ro
        ports:
          - 8090:8080
        restart: unless-stopped

  '';

  # ---------------------------------------------------------------------------
  # Environment template — copied to NFS on first boot, user edits with secrets
  # ---------------------------------------------------------------------------
  environment.etc."arr/env.template".text = ''
    # Arr Stack Environment Configuration
    # Edit this file with your actual credentials
    # This file persists on TrueNAS NFS — survives NixOS rebuilds

    TIMEZONE=${tz}

    # ProtonVPN WireGuard
    WIREGUARD_PRIVATE_KEY=
    WIREGUARD_ADDRESSES=

    # Arr Service API Keys (get from each app's Settings > General after first launch)
    RADARR_API_KEY=
    SONARR_API_KEY=
    PROWLARR_API_KEY=
    LIDARR_API_KEY=
    BAZARR_API_KEY=

  '';

  # ---------------------------------------------------------------------------
  # Initial config templates — copied to NFS on first boot only
  # Apps may modify these at runtime; NixOS won't overwrite them
  # ---------------------------------------------------------------------------

  # qBittorrent configuration
  environment.etc."arr/qBittorrent.conf".text = ''
    [Preferences]

    [LegalNotice]
    Accepted=true

    [BitTorrent]
    Session\DefaultSavePath=/data/media/downloads/torrents
    Session\TempPath=/data-scratch
    Session\TempPathEnabled=true
    Session\Port=6881
    Session\QueueingSystemEnabled=true
    Session\MaxActiveDownloads=5
    Session\MaxActiveTorrents=10
    Session\MaxActiveUploads=5
    Session\GlobalMaxSeedingMinutes=10080

    [Network]
    Proxy\OnlyForTorrents=false

    [WebUI]
    Port=8701
    Address=*
    LocalHostAuth=false
    AuthSubnetWhitelistEnabled=false
    CSRFProtection=true
    ClickjackingProtection=true
    HostHeaderValidation=true
    SecureCookie=true
    Username=admin
  '';

  # SABnzbd configuration
  environment.etc."arr/sabnzbd.ini".text = ''
    [misc]
    host = 0.0.0.0
    port = 8080
    download_dir = /data-scratch
    complete_dir = /data/media/downloads/usenet
    permissions = 0775
    auto_browser = 0
    replace_illegal = 1
    replace_spaces = 0
    fail_hopeless_jobs = 1
    auto_disconnect = 1
    pre_check = 1
    max_art_tries = 3
    top_only = 0
    history_retention = 30d

    [categories]
    [[*]]
    name = *
    dir = ""
    priority = 0

    [[movies]]
    name = movies
    dir = movies
    priority = -100

    [[tv]]
    name = tv
    dir = tv
    priority = -100

    [[music]]
    name = music
    dir = music
    priority = -100
  '';

  # Slskd configuration
  environment.etc."arr/slskd.yml".text = ''
    web:
      port: 5030
      authentication:
        username: slskd
        password: slskd

    directories:
      downloads: /downloads
      incomplete: /app/incomplete

    soulseek:
      listen_port: 58485
      description: |
        A slskd user. https://github.com/slskd/slskd

    shares:
      directories:
        - /music
      filters:
        - \.ini$
        - Thumbs.db$
        - \.DS_Store$

    global:
      upload:
        slots: 10
      download:
        slots: 100
  '';

  # ---------------------------------------------------------------------------
  # Declarative configs — bind-mounted read-only into containers
  # ---------------------------------------------------------------------------

  # Recyclarr configuration (TRaSH Guides quality profiles)
  environment.etc."arr/recyclarr.yml".text = ''
    radarr:
      movies:
        base_url: http://localhost:7878
        api_key: __RADARR_API_KEY__

        quality_definition:
          type: movie

        quality_profiles:
          - name: HD-1080p
            reset_unmatched_scores:
              enabled: true
            upgrade:
              allowed: true
              until_quality: Bluray-1080p
              until_score: 10000
            min_format_score: 0
            quality_sort: top
            qualities:
              - name: Bluray-1080p
              - name: WEB 1080p
                qualities:
                  - WEBDL-1080p
                  - WEBRip-1080p
              - name: HDTV-1080p

    sonarr:
      tv:
        base_url: http://localhost:8989
        api_key: __SONARR_API_KEY__

        quality_definition:
          type: series

        quality_profiles:
          - name: HD-1080p
            reset_unmatched_scores:
              enabled: true
            upgrade:
              allowed: true
              until_quality: Bluray-1080p
              until_score: 10000
            min_format_score: 0
            quality_sort: top
            qualities:
              - name: Bluray-1080p
              - name: WEB 1080p
                qualities:
                  - WEBDL-1080p
                  - WEBRip-1080p
              - name: HDTV-1080p
  '';

  # Buildarr configuration (infrastructure as code for *arr apps)
  environment.etc."arr/buildarr.yml".text = ''
    buildarr:
      watch_config: false
      update_days:
        - monday
      update_times:
        - "03:00"

    radarr:
      hostname: localhost
      port: 7878
      protocol: http
      api_key: __RADARR_API_KEY__

      settings:
        media_management:
          rename_movies: true
          replace_illegal_characters: true
          standard_movie_format: "{Movie Title} ({Release Year}) {Quality Full}"
          movie_folder_format: "{Movie Title} ({Release Year})"

        download_clients:
          enable_completed_download_handling: true
          redownload_failed: true

    sonarr:
      hostname: localhost
      port: 8989
      protocol: http
      api_key: __SONARR_API_KEY__

      settings:
        media_management:
          rename_episodes: true
          replace_illegal_characters: true
          standard_episode_format: "{Series Title} - S{season:00}E{episode:00} - {Episode Title} {Quality Full}"
          series_folder_format: "{Series Title}"
          season_folder_format: "Season {season}"

        download_clients:
          enable_completed_download_handling: true
          redownload_failed: true

    lidarr:
      hostname: localhost
      port: 8686
      protocol: http
      api_key: __LIDARR_API_KEY__

      settings:
        media_management:
          rename_tracks: true
          replace_illegal_characters: true
          standard_track_format: "{Album Title} ({Release Year})/{Artist Name} - {Album Title} - {track:00} - {Track Title}"
          multi_disc_track_format: "{Album Title} ({Release Year})/{Medium Format} {medium:00}/{Artist Name} - {Album Title} - {track:00} - {Track Title}"
          artist_folder_format: "{Artist Name}"

        download_clients:
          enable_completed_download_handling: true
          redownload_failed: true

    bazarr:
      hostname: localhost
      port: 6767
      protocol: http
      api_key: __BAZARR_API_KEY__

    prowlarr:
      hostname: localhost
      port: 9696
      protocol: http
      api_key: __PROWLARR_API_KEY__
  '';

  # ---------------------------------------------------------------------------
  # Systemd services
  # ---------------------------------------------------------------------------

  # Initialize NFS directories and seed configs on first boot
  systemd.services.arr-init = {
    description = "Initialize arr stack directories and configs";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    unitConfig.RequiresMountsFor = "${dataDir} ${mediaDir} ${scratchDir}";

    path = [ pkgs.coreutils pkgs.gnused ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "arr-init" ''
        set -euo pipefail

        # Create service directories on NFS
        mkdir -p ${dataDir}/gluetun
        mkdir -p ${dataDir}/qbittorrent/qBittorrent/config
        mkdir -p ${dataDir}/sabnzbd
        mkdir -p ${dataDir}/radarr
        mkdir -p ${dataDir}/sonarr
        mkdir -p ${dataDir}/lidarr
        mkdir -p ${dataDir}/bazarr
        mkdir -p ${dataDir}/slskd
        mkdir -p ${dataDir}/prowlarr
        mkdir -p ${dataDir}/recyclarr
        mkdir -p ${dataDir}/buildarr
        mkdir -p ${dataDir}/glance
        # Ensure download directories exist on media mount
        mkdir -p ${mediaDir}/downloads/torrents
        mkdir -p ${mediaDir}/downloads/usenet
        mkdir -p ${mediaDir}/downloads/soulseek
        chown -R 1000:1000 ${mediaDir}/downloads

        # Symlink old incomplete path to scratch mount so queued jobs still work
        # (containers see /data/media/downloads/incomplete → /data-scratch)
        rm -rf ${mediaDir}/downloads/incomplete
        ln -sf /data-scratch ${mediaDir}/downloads/incomplete

        # Copy .env template if not present
        if [ ! -f ${dataDir}/env ]; then
          cp /etc/arr/env.template ${dataDir}/env
          echo "Created ${dataDir}/env from template — edit with your secrets"
        fi

        # Copy initial configs if not present (apps modify these at runtime)
        if [ ! -f ${dataDir}/qbittorrent/qBittorrent/config/qBittorrent.conf ]; then
          cp /etc/arr/qBittorrent.conf ${dataDir}/qbittorrent/qBittorrent/config/qBittorrent.conf
        fi
        if [ ! -f ${dataDir}/sabnzbd/sabnzbd.ini ]; then
          cp /etc/arr/sabnzbd.ini ${dataDir}/sabnzbd/sabnzbd.ini
        fi
        if [ ! -f ${dataDir}/slskd/slskd.yml ]; then
          cp /etc/arr/slskd.yml ${dataDir}/slskd/slskd.yml
        fi

        # Fix download paths — ensure incomplete downloads use scratch pool
        # Note: qBittorrent stores runtime config in parent dir, not config/ subdir
        QB_CONF="${dataDir}/qbittorrent/qBittorrent/qBittorrent.conf"
        if [ -f "$QB_CONF" ]; then
          sed -i 's|Session\\TempPath=.*|Session\\TempPath=/data-scratch|' "$QB_CONF"
          sed -i 's|Session\\TempPathEnabled=.*|Session\\TempPathEnabled=true|' "$QB_CONF"
          sed -i 's|Session\\DefaultSavePath=.*|Session\\DefaultSavePath=/data/media/downloads/torrents|' "$QB_CONF"
        fi

        SAB_CONF="${dataDir}/sabnzbd/sabnzbd.ini"
        if [ -f "$SAB_CONF" ]; then
          sed -i 's|^download_dir = .*|download_dir = /data-scratch|' "$SAB_CONF"
          sed -i 's|^complete_dir = .*|complete_dir = /data/media/downloads/usenet|' "$SAB_CONF"
        fi

        # Symlink .env to compose directory
        ln -sf ${dataDir}/env ${composeDir}/.env

        echo "Arr stack initialization complete"
      '';
    };
  };

  # Arr stack docker-compose service
  # Uses Type=simple with a foreground process that monitors container health.
  # Restarts automatically if the monitor exits (containers down, NFS hang, etc.)
  systemd.services.arr-stack = {
    description = "Arr Media Stack";
    after = [ "docker.service" "network-online.target" "arr-init.service" ];
    wants = [ "network-online.target" ];
    requires = [ "docker.service" "arr-init.service" ];
    wantedBy = [ "multi-user.target" ];

    unitConfig.RequiresMountsFor = "${dataDir} ${mediaDir} ${scratchDir}";

    path = [ pkgs.docker pkgs.docker-compose pkgs.coreutils ];

    serviceConfig = {
      Type = "simple";
      WorkingDirectory = composeDir;
      ExecStartPre = "${pkgs.docker-compose}/bin/docker-compose up -d";
      ExecStart = pkgs.writeShellScript "arr-stack-monitor" ''
        set -euo pipefail

        # Wait for containers to initialize, then create compatibility symlinks
        # Old queued jobs reference /data/downloads/* but mount is now at /data/media
        sleep 15
        for ctr in sabnzbd qbittorrent; do
          docker exec "$ctr" sh -c 'mkdir -p /data && ln -sfn /data/media/downloads /data/downloads' 2>/dev/null || true
        done

        # Monitor loop — exits non-zero if critical containers are down,
        # which triggers systemd Restart=on-failure
        while true; do
          sleep 60

          # Check that gluetun (VPN gateway) is running — all arr apps depend on it
          if ! docker inspect --format='{{.State.Running}}' gluetun 2>/dev/null | grep -q true; then
            echo "gluetun is not running, restarting stack..."
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
