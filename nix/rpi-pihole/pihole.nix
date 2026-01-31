{ pkgs, lib, constants, ... }: {
  # Enable Docker for Pi-hole containers
  virtualisation.docker.enable = true;

  # Pi-hole systemd service
  systemd.services.pihole = {
    description = "Pi-hole DNS Server";
    after = [ "docker.service" "network-online.target" ];
    wants = [ "network-online.target" ];
    requires = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];

    path = [ pkgs.docker pkgs.docker-compose ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      WorkingDirectory = "/opt/pihole";
      ExecStart = "${pkgs.docker-compose}/bin/docker-compose up -d";
      ExecStop = "${pkgs.docker-compose}/bin/docker-compose down";
      Restart = "on-failure";
      RestartSec = "10s";
    };
  };

  # Create docker-compose.yml for Pi-hole
  environment.etc."pihole/docker-compose.yml".text = ''
    services:
      pihole:
        image: pihole/pihole:${constants.piholeVersion}
        container_name: pihole
        ports:
          - "53:53/tcp"
          - "53:53/udp"
          - "80:80/tcp"
        environment:
          TZ: "${constants.timezone}"
          WEBPASSWORD: "changeme"
          FTLCONF_LOCAL_IPV4: "192.168.0.53"
          PIHOLE_DNS_: "unbound#5335"
          DNSMASQ_LISTENING: "all"
        volumes:
          - ./etc-pihole:/etc/pihole
          - ./etc-dnsmasq.d:/etc/dnsmasq.d
        cap_add:
          - NET_ADMIN
        restart: unless-stopped
        networks:
          - pihole_net
        depends_on:
          - unbound
        healthcheck:
          test: ["CMD", "dig", "+norecurse", "+retry=0", "@127.0.0.1", "pi.hole"]
          interval: 30s
          timeout: 10s
          retries: 3

      unbound:
        image: mvance/unbound:${constants.unboundVersion}
        container_name: unbound
        ports:
          - "5335:5335/tcp"
          - "5335:5335/udp"
        restart: unless-stopped
        networks:
          - pihole_net
        healthcheck:
          test: ["CMD", "drill", "@127.0.0.1", "-p", "5335", "cloudflare.com"]
          interval: 30s
          timeout: 10s
          retries: 3

    networks:
      pihole_net:
        driver: bridge
  '';

  # Copy docker-compose.yml to working directory
  systemd.tmpfiles.rules = [
    "d /opt/pihole 0755 root root -"
    "d /opt/pihole/etc-pihole 0755 root root -"
    "d /opt/pihole/etc-dnsmasq.d 0755 root root -"
    "L+ /opt/pihole/docker-compose.yml - - - - /etc/pihole/docker-compose.yml"
  ];

  # Prometheus node exporter for monitoring
  services.prometheus.exporters.node = {
    enable = true;
    enabledCollectors = [ "systemd" "textfile" ];
    port = 9100;
    openFirewall = true;
  };
}
