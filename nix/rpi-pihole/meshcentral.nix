{ pkgs, ... }: {
  # MeshCentral systemd service (Intel AMT web management — KVM, SOL, IDER, Power)
  systemd.services.meshcentral = {
    description = "MeshCentral Intel AMT Management Console";
    after = [ "docker.service" "network-online.target" ];
    wants = [ "network-online.target" ];
    requires = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];

    path = [ pkgs.docker pkgs.docker-compose ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      WorkingDirectory = "/opt/meshcentral";
      ExecStart = "${pkgs.docker-compose}/bin/docker-compose up -d";
      ExecStop = "${pkgs.docker-compose}/bin/docker-compose down";
      Restart = "on-failure";
      RestartSec = "10s";
    };
  };

  # docker-compose.yml for MeshCentral (multi-arch image, supports linux/arm64).
  # AMT KVM works via WebRTC — exposed on 8443 to avoid Pi-hole's port 80.
  environment.etc."meshcentral/docker-compose.yml".text = ''
    services:
      meshcentral:
        image: typhonragewind/meshcentral:latest
        container_name: meshcentral
        ports:
          - "8443:443"
        environment:
          - HOSTNAME=192.168.0.53
          - REVERSE_PROXY=false
          - IFRAME=false
          - ALLOW_NEW_ACCOUNTS=true
          - WEBRTC=true
          - ALLOWPLUGINS=false
          - LOCALSESSIONRECORDING=false
          - MINIFY=true
        volumes:
          - /opt/meshcentral/data:/opt/meshcentral/meshcentral-data
          - /opt/meshcentral/files:/opt/meshcentral/meshcentral-files
          - /opt/meshcentral/backup:/opt/meshcentral/meshcentral-backups
          - /opt/meshcentral/web:/opt/meshcentral/meshcentral-web
        restart: unless-stopped
  '';

  # Working directory + persistent data dirs + symlink config
  systemd.tmpfiles.rules = [
    "d /opt/meshcentral 0755 root root -"
    "d /opt/meshcentral/data 0755 root root -"
    "d /opt/meshcentral/files 0755 root root -"
    "d /opt/meshcentral/backup 0755 root root -"
    "d /opt/meshcentral/web 0755 root root -"
    "L+ /opt/meshcentral/docker-compose.yml - - - - /etc/meshcentral/docker-compose.yml"
  ];
}
