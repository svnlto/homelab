{ pkgs, ... }: {
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
    "10.0.1.101" = [
      "prom-write.shared.h.svenlito.com"
      "otlp.shared.h.svenlito.com"
    ];
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

  # Ship the Pi's journald (dumper + the pihole/unbound containers, which now
  # log to journald) AND its Prometheus metrics to ClickStack over OTLP. vmagent
  # keeps remote-writing the same metrics to Prometheus in parallel — it holds
  # the existing 90-day WAN/ISP evidence, so it is retired only once ClickStack
  # has accumulated equivalent history (Plan B). The ingestion key arrives
  # out-of-band via an EnvironmentFile because the NixOS config is in Git.
  systemd.tmpfiles.rules = [ "d /var/lib/otelcol 0700 root root -" ];

  services.opentelemetry-collector = {
    enable = true;
    # journald receiver is a contrib component; the default package lacks it.
    package = pkgs.opentelemetry-collector-contrib;
    settings = {
      extensions.file_storage.directory = "/var/lib/opentelemetry-collector";
      receivers.journald = {
        directory = "/var/log/journal";
        # Resume from the persisted cursor; only ship new entries on first start
        # so the existing journal history is not replayed into ClickStack.
        start_at = "end";
        storage = "file_storage";
        # The receiver emits the whole journal entry as a body map, which the
        # ClickStack exporter flattens into attributes — leaving the log Body
        # empty and unreadable in HyperDX. Promote the fields worth filtering on
        # to attributes, then collapse the body to the MESSAGE string. Each move
        # is guarded by an existence check: a bare move errors on every entry
        # missing that field (CONTAINER_NAME is absent on all non-container
        # units, _SYSTEMD_UNIT on kernel messages).
        operators = [
          {
            type = "move";
            "if" = "'_SYSTEMD_UNIT' in body";
            from = "body._SYSTEMD_UNIT";
            to = "attributes[\"systemd.unit\"]";
          }
          {
            type = "move";
            "if" = "'CONTAINER_NAME' in body";
            from = "body.CONTAINER_NAME";
            to = "attributes[\"container.name\"]";
          }
          {
            type = "move";
            "if" = "'PRIORITY' in body";
            from = "body.PRIORITY";
            to = "attributes[\"priority\"]";
          }
          {
            type = "move";
            "if" = "'MESSAGE' in body";
            from = "body.MESSAGE";
            to = "body";
          }
        ];
      };
      # Scrape the same local exporters vmagent does, so ClickStack gets the Pi's
      # metrics too. Duplicated from vmagent-scrape.yml rather than shared: the
      # plan forbids touching vmagent, and this scrape list collapses to the sole
      # copy once vmagent retires in Plan B.
      receivers.prometheus.config.scrape_configs = [
        {
          job_name = "smokeping";
          static_configs = [ { targets = [ "127.0.0.1:9374" ]; } ];
        }
        {
          job_name = "node";
          static_configs = [ { targets = [ "127.0.0.1:9100" ]; } ];
        }
        {
          job_name = "blackbox-dns";
          metrics_path = "/probe";
          params.module = [ "dns_udp" ];
          static_configs = [
            {
              targets = [
                "1.1.1.1:53"
                "8.8.8.8:53"
                "9.9.9.9:53"
              ];
              labels.rung = "3";
            }
          ];
          relabel_configs = [
            {
              source_labels = [ "__address__" ];
              target_label = "__param_target";
            }
            {
              source_labels = [ "__param_target" ];
              target_label = "instance";
            }
            {
              target_label = "__address__";
              replacement = "127.0.0.1:9115";
            }
          ];
        }
        {
          job_name = "blackbox-http";
          metrics_path = "/probe";
          params.module = [ "http_2xx" ];
          static_configs = [
            {
              targets = [ "https://www.cloudflare.com" ];
              labels.rung = "4";
            }
          ];
          relabel_configs = [
            {
              source_labels = [ "__address__" ];
              target_label = "__param_target";
            }
            {
              source_labels = [ "__param_target" ];
              target_label = "instance";
            }
            {
              target_label = "__address__";
              replacement = "127.0.0.1:9115";
            }
          ];
        }
      ];
      # Receive OTLP traces from the local dumper (service.name=dumper).
      receivers.otlp.protocols.http.endpoint = "127.0.0.1:4318";
      processors = {
        memory_limiter = {
          check_interval = "1s";
          limit_mib = 200;
          spike_limit_mib = 50;
        };
        resource.attributes = [
          {
            key = "host.name";
            value = "rpi-pihole";
            action = "upsert";
          }
          {
            key = "service.name";
            value = "rpi-pihole";
            action = "upsert";
          }
        ];
        batch = { };
      };
      exporters.otlphttp = {
        endpoint = "https://otlp.shared.h.svenlito.com";
        compression = "gzip";
        headers.authorization = "\${env:CLICKSTACK_API_KEY}";
        sending_queue = {
          enabled = true;
          storage = "file_storage";
        };
      };
      service = {
        extensions = [ "file_storage" ];
        pipelines.logs = {
          receivers = [ "journald" ];
          processors = [
            "memory_limiter"
            "resource"
            "batch"
          ];
          exporters = [ "otlphttp" ];
        };
        pipelines.metrics = {
          receivers = [ "prometheus" ];
          processors = [
            "memory_limiter"
            "resource"
            "batch"
          ];
          exporters = [ "otlphttp" ];
        };
        # No resource processor here: it force-upserts service.name=rpi-pihole,
        # which would clobber the dumper's own service.name on its spans.
        pipelines.traces = {
          receivers = [ "otlp" ];
          processors = [
            "memory_limiter"
            "batch"
          ];
          exporters = [ "otlphttp" ];
        };
      };
    };
  };

  systemd.services.opentelemetry-collector.serviceConfig.EnvironmentFile = "/var/lib/otelcol/env";
}
