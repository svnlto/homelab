_: {
  # blackbox_exporter — DNS resolution timing and HTTP TTFB for the WAN
  # diagnostic ladder. The NixOS module grants CAP_NET_RAW unconditionally,
  # so ICMP probes work without extra configuration.
  services.prometheus.exporters.blackbox = {
    enable = true;
    port = 9115;
    openFirewall = true;
    configFile = builtins.toFile "blackbox.yml" (
      builtins.toJSON {
        modules = {
          # Default preferred_ip_protocol is ip6 — must be overridden.
          icmp_v4 = {
            prober = "icmp";
            timeout = "5s";
            icmp = {
              preferred_ip_protocol = "ip4";
              ip_protocol_fallback = false;
              payload_size = 56;
            };
          };
          # The resolver is the scrape TARGET, not a field here.
          dns_udp = {
            prober = "dns";
            timeout = "5s";
            dns = {
              query_name = "cloudflare.com";
              query_type = "A";
              transport_protocol = "udp";
              preferred_ip_protocol = "ip4";
            };
          };
          http_2xx = {
            prober = "http";
            timeout = "10s";
            http = {
              preferred_ip_protocol = "ip4";
              valid_status_codes = [ ];
            };
          };
        };
      }
    );
  };

  environment.etc."smokeping/smokeping.yml".source = ./smokeping.yml;

  # smokeping_prober — real ICMP histograms. Not in nixpkgs, so it runs as a
  # container alongside the existing pihole/unbound ones. NET_RAW is required
  # for raw ICMP sockets; host networking so probes leave the real interface.
  virtualisation.oci-containers.backend = "docker";
  virtualisation.oci-containers.containers.smokeping-prober = {
    image = "quay.io/superq/smokeping-prober:v0.12.0";
    extraOptions = [
      "--network=host"
      "--cap-add=NET_RAW"
    ];
    volumes = [ "/etc/smokeping/smokeping.yml:/config/smokeping.yml:ro" ];
    cmd = [
      "--config.file=/config/smokeping.yml"
      "--web.listen-address=:9374"
    ];
  };

  environment.etc."vmagent/scrape.yml".source = ./vmagent-scrape.yml;

  # MagicDNS resolves this hostname to a tailnet address the ACL denies, while the
  # LAN LoadBalancer is directly reachable. /etc/hosts beats MagicDNS via nsswitch,
  # so this pins vmagent to VLAN 20 -> MikroTik -> VLAN 30. TLS still validates
  # because the hostname is unchanged — only the address it resolves to.
  networking.hosts = {
    "10.0.1.101" = [ "prom-write.shared.h.svenlito.com" ];
  };

  # vmagent buffers to disk and remote-writes to the cluster Prometheus.
  # Chosen over Prometheus agent mode because maxDiskUsagePerURL bounds
  # worst-case SD usage during a long outage; Prometheus agent's own docs
  # contradict themselves on whether its buffer is 2h or 4h.
  #
  # services.vmagent.prometheusConfig takes a Nix attrset (rendered to YAML
  # by the module), not a file path, so the scrape config is passed via
  # -promscrape.config instead of that option. remoteWrite.basicAuthUsername/
  # basicAuthPasswordFile already generate the -remoteWrite.basicAuth.* flags
  # and wire the password through systemd's LoadCredential (readable by root,
  # staged for the DynamicUser service) — passing them again via extraArgs
  # would duplicate the flags.
  services.vmagent = {
    enable = true;
    remoteWrite = {
      url = "https://prom-write.shared.h.svenlito.com/api/v1/write";
      basicAuthUsername = "promwrite";
      basicAuthPasswordFile = "/etc/vmagent-password";
    };
    extraArgs = [
      "-promscrape.config=/etc/vmagent/scrape.yml"
      "-remoteWrite.maxDiskUsagePerURL=4GB"
    ];
  };
}
