{ pkgs, constants, ... }: {
  # Enable Docker for Pi-hole containers
  virtualisation.docker = {
    enable = true;
    # Log rotation to prevent SD card fill
    daemon.settings = {
      log-driver = "json-file";
      log-opts = {
        max-size = "10m";
        max-file = "3";
      };
    };
  };

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
        network_mode: host
        environment:
          TZ: "${constants.timezone}"
          WEBPASSWORD: "changeme"
          FTLCONF_LOCAL_IPV4: "192.168.0.53"
          PIHOLE_DNS_: "127.0.0.1#5335"
          FTLCONF_dns_listeningMode: "all"
        volumes:
          - /opt/pihole/etc-pihole:/etc/pihole
          - /opt/pihole/etc-dnsmasq.d:/etc/dnsmasq.d
        cap_add:
          - NET_ADMIN
        restart: unless-stopped
        healthcheck:
          test: ["CMD", "dig", "+norecurse", "+retry=0", "@127.0.0.1", "pi.hole"]
          interval: 30s
          timeout: 10s
          retries: 3

      unbound:
        image: ${constants.unboundImage}
        container_name: unbound
        network_mode: host
        volumes:
          - /opt/unbound/unbound.conf:/opt/unbound/etc/unbound/unbound.conf:ro
        restart: unless-stopped
        healthcheck:
          test: ["CMD", "drill", "@127.0.0.1", "-p", "5335", "cloudflare.com"]
          interval: 30s
          timeout: 10s
          retries: 3
  '';

  # Create Unbound configuration file (port 5335, localhost only)
  # Forwards to Mullvad DNS-over-TLS (ISP cannot see DNS queries)
  environment.etc."unbound/unbound.conf".text = ''
    server:
      verbosity: 0
      interface: 127.0.0.1@5335
      port: 5335
      do-ip4: yes
      do-udp: yes
      do-tcp: yes
      do-ip6: no
      prefer-ip6: no

      # Access control — localhost only (Pi-hole queries Unbound)
      access-control: 127.0.0.0/8 allow
      access-control: 0.0.0.0/0 refuse

      # DNSSEC hardening
      harden-glue: yes
      harden-dnssec-stripped: yes
      harden-below-nxdomain: yes

      # TLS for upstream forwarding
      tls-cert-bundle: /etc/ssl/certs/ca-certificates.crt

      # Cache tuning
      cache-min-ttl: 300
      cache-max-ttl: 86400
      prefetch: yes
      prefetch-key: yes

      use-caps-for-id: no
      edns-buffer-size: 1232
      num-threads: 1
      so-rcvbuf: 1m
      private-address: 192.168.0.0/16
      private-address: 172.16.0.0/12
      private-address: 10.0.0.0/8
      private-address: fd00::/8
      private-address: fe80::/10

    # Forward all queries to Mullvad DNS over TLS (no-logging, Sweden)
    forward-zone:
      name: "."
      forward-tls-upstream: yes
      forward-addr: 194.242.2.2@853#dns.mullvad.net
      forward-addr: 193.19.108.2@853#dns.mullvad.net
  '';

  # Copy docker-compose.yml and configs to working directory
  systemd.tmpfiles.rules = [
    "d /opt/pihole 0755 root root -"
    "d /opt/pihole/etc-pihole 0755 root root -"
    "d /opt/pihole/etc-dnsmasq.d 0755 root root -"
    "d /opt/unbound 0755 root root -"
    "L+ /opt/pihole/docker-compose.yml - - - - /etc/pihole/docker-compose.yml"
    "L+ /opt/unbound/unbound.conf - - - - /etc/unbound/unbound.conf"
  ];

  # Prometheus node exporter for monitoring
  services.prometheus.exporters.node = {
    enable = true;
    enabledCollectors = [ "systemd" "textfile" ];
    port = 9100;
    openFirewall = true;
  };
}
