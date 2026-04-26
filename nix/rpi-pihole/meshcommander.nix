{ pkgs, ... }: {
  # MeshCommander systemd service (Intel AMT web management console)
  systemd.services.meshcommander = {
    description = "MeshCommander Intel AMT Management Console";
    after = [ "docker.service" "network-online.target" ];
    wants = [ "network-online.target" ];
    requires = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];

    path = [ pkgs.docker pkgs.docker-compose ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      WorkingDirectory = "/opt/meshcommander";
      ExecStart = "${pkgs.docker-compose}/bin/docker-compose up -d";
      ExecStop = "${pkgs.docker-compose}/bin/docker-compose down";
      Restart = "on-failure";
      RestartSec = "10s";
    };
  };

  # Create docker-compose.yml for MeshCommander
  environment.etc."meshcommander/docker-compose.yml".text = ''
    services:
      meshcommander:
        image: taskinen/meshcommander:latest
        container_name: meshcommander
        ports:
          - "3000:3000"
        restart: unless-stopped
  '';

  # Create working directory and symlink config
  systemd.tmpfiles.rules = [
    "d /opt/meshcommander 0755 root root -"
    "L+ /opt/meshcommander/docker-compose.yml - - - - /etc/meshcommander/docker-compose.yml"
  ];
}
