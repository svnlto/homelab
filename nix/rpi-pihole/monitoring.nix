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
}
