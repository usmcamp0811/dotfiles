{ lib
, config
, pkgs
, ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.services.adguard;
in
{
  options.campground.services.adguard = with types; {
    enable = mkBoolOpt false "Enable AdGuard Home DNS server and ad blocker";

    package = mkOpt package pkgs.adguardhome "The AdGuard Home package to use";

    host = mkOpt str "0.0.0.0" "Host address to bind the web interface to";

    port = mkOpt port 3000 "Port for the web interface";

    openFirewall = mkBoolOpt false "Open firewall ports for AdGuard Home";

    mutableSettings = mkBoolOpt true "Allow settings to be changed via web interface";

    dns = {
      port = mkOpt port 53 "DNS server port";

      bindHosts = mkOpt (listOf str) [ "0.0.0.0" ] "DNS server bind addresses";

      upstreamDns = mkOpt (listOf str) [
        "https://dns.cloudflare.com/dns-query"
        "https://dns.google/dns-query"
        "1.1.1.1"
        "8.8.8.8"
      ] "Upstream DNS servers (supports DNS-over-HTTPS, DNS-over-TLS, DNS-over-QUIC)";

      bootstrapDns = mkOpt (listOf str) [
        "1.1.1.1"
        "8.8.8.8"
      ] "Bootstrap DNS servers for resolving DoH/DoT hostnames";

      ratelimit = mkOpt int 20 "DDoS protection: max number of requests per second from a client";

      blockingMode = mkOpt (enum [ "default" "nxdomain" "null_ip" "custom_ip" ]) "default"
        "How to respond to blocked domains (default, nxdomain, null_ip, custom_ip)";

      blockingIpv4 = mkOpt str "" "Custom IPv4 for blocked domains when blockingMode is custom_ip";

      blockingIpv6 = mkOpt str "" "Custom IPv6 for blocked domains when blockingMode is custom_ip";

      enableEDNSClientSubnet = mkBoolOpt false "Enable EDNS Client Subnet (ECS)";

      enableDNSSEC = mkBoolOpt true "Enable DNSSEC";

      cacheSize = mkOpt int 4194304 "DNS cache size in bytes (default: 4MB)";

      cacheTtlMin = mkOpt int 0 "Minimum TTL for DNS cache entries (0 = use upstream TTL)";

      cacheTtlMax = mkOpt int 0 "Maximum TTL for DNS cache entries (0 = use upstream TTL)";

      enableParallelUpstreamQueries = mkBoolOpt false "Query all upstream servers in parallel";
    };

    filtering = {
      enable = mkBoolOpt true "Enable DNS filtering";

      updateInterval = mkOpt int 24 "How often to update filters (in hours)";

      filters = mkOpt (listOf (submodule {
        options = {
          enabled = mkOption {
            type = bool;
            default = true;
            description = "Whether this filter is enabled";
          };
          name = mkOption {
            type = str;
            description = "Filter name";
          };
          url = mkOption {
            type = str;
            description = "Filter URL";
          };
        };
      })) [
        {
          enabled = true;
          name = "AdGuard DNS filter";
          url = "https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt";
        }
      ] "Filter lists to enable";
    };

    queryLog = {
      enabled = mkBoolOpt true "Enable query logging";

      interval = mkOpt str "2160h" "How long to keep query logs (e.g., 2160h = 90 days)";

      anonymizeClientIp = mkBoolOpt false "Anonymize client IP addresses in logs";
    };

    statistics = {
      enabled = mkBoolOpt true "Enable statistics";

      interval = mkOpt str "24h" "Statistics retention period";
    };

    dhcp = {
      enable = mkBoolOpt false "Enable DHCP server";

      interface = mkOpt str "" "Network interface for DHCP server";

      gatewayIp = mkOpt str "" "Gateway IP address";

      subnetMask = mkOpt str "" "Subnet mask";

      rangeStart = mkOpt str "" "DHCP range start IP";

      rangeEnd = mkOpt str "" "DHCP range end IP";

      leaseDuration = mkOpt int 86400 "DHCP lease duration in seconds (default: 24 hours)";
    };

    tls = {
      enable = mkBoolOpt false "Enable DNS-over-TLS and DNS-over-HTTPS";

      port = mkOpt port 853 "DNS-over-TLS port";

      portHttps = mkOpt port 443 "DNS-over-HTTPS port";

      portQuic = mkOpt port 853 "DNS-over-QUIC port";

      certificatePath = mkOpt str "" "Path to TLS certificate";

      privateKeyPath = mkOpt str "" "Path to TLS private key";

      serverName = mkOpt str "" "Server name for TLS certificate";
    };

    safeBrowsing = {
      enable = mkBoolOpt false "Enable safe browsing";
    };

    parentalControl = {
      enable = mkBoolOpt false "Enable parental control";
    };

    safeSearch = {
      enable = mkBoolOpt false "Enable safe search enforcement";
    };

    extraArgs = mkOpt (listOf str) [ ] "Extra command-line arguments to pass to AdGuard Home";

    extraSettings = mkOpt attrs { } "Additional settings to merge into AdGuard Home configuration";
  };

  config = mkIf cfg.enable {
    # Configure the base AdGuard Home service
    services.adguardhome = {
      enable = true;
      inherit (cfg) package mutableSettings openFirewall extraArgs;

      settings = mkMerge [
        {
          # HTTP API configuration
          bind_host = cfg.host;
          bind_port = cfg.port;

          # DNS configuration
          dns = {
            bind_hosts = cfg.dns.bindHosts;
            port = cfg.dns.port;
            upstream_dns = cfg.dns.upstreamDns;
            bootstrap_dns = cfg.dns.bootstrapDns;
            ratelimit = cfg.dns.ratelimit;
            blocking_mode = cfg.dns.blockingMode;
            enable_dnssec = cfg.dns.enableDNSSEC;
            edns_client_subnet = {
              enabled = cfg.dns.enableEDNSClientSubnet;
            };
            cache_size = cfg.dns.cacheSize;
            cache_ttl_min = cfg.dns.cacheTtlMin;
            cache_ttl_max = cfg.dns.cacheTtlMax;
            all_servers = cfg.dns.enableParallelUpstreamQueries;
          }
          // (optionalAttrs (cfg.dns.blockingMode == "custom_ip") {
            blocking_ipv4 = cfg.dns.blockingIpv4;
            blocking_ipv6 = cfg.dns.blockingIpv6;
          });

          # Filtering configuration
          filters = map
            (filter: {
              enabled = filter.enabled;
              name = filter.name;
              url = filter.url;
            })
            cfg.filtering.filters;

          filtering = {
            enabled = cfg.filtering.enable;
            filters_update_interval = cfg.filtering.updateInterval;
          };

          # Query log configuration
          querylog = {
            enabled = cfg.queryLog.enabled;
            interval = cfg.queryLog.interval;
            anonymize_client_ip = cfg.queryLog.anonymizeClientIp;
          };

          # Statistics configuration
          statistics = {
            enabled = cfg.statistics.enabled;
            interval = cfg.statistics.interval;
          };

          # Safe browsing / Parental control
          safebrowsing = {
            enabled = cfg.safeBrowsing.enable;
          };

          parental = {
            enabled = cfg.parentalControl.enable;
          };

          safesearch = {
            enabled = cfg.safeSearch.enable;
          };
        }

        # DHCP configuration (optional)
        (optionalAttrs cfg.dhcp.enable {
          dhcp = {
            enabled = true;
            interface_name = cfg.dhcp.interface;
            gateway_ip = cfg.dhcp.gatewayIp;
            subnet_mask = cfg.dhcp.subnetMask;
            range_start = cfg.dhcp.rangeStart;
            range_end = cfg.dhcp.rangeEnd;
            lease_duration = cfg.dhcp.leaseDuration;
          };
        })

        # TLS configuration (optional)
        (optionalAttrs cfg.tls.enable {
          tls = {
            enabled = true;
            port_dns_over_tls = cfg.tls.port;
            port_dns_over_quic = cfg.tls.portQuic;
            port_https = cfg.tls.portHttps;
            certificate_path = cfg.tls.certificatePath;
            private_key_path = cfg.tls.privateKeyPath;
            server_name = cfg.tls.serverName;
          };
        })

        # User-provided extra settings
        cfg.extraSettings
      ];
    };

    # Open firewall ports if requested
    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ]
        ++ optional (cfg.dns.port != 53) cfg.dns.port
        ++ optional cfg.tls.enable cfg.tls.port
        ++ optional cfg.tls.enable cfg.tls.portHttps;

      allowedUDPPorts = [ cfg.dns.port ]
        ++ optional cfg.dhcp.enable 67
        ++ optional cfg.tls.enable cfg.tls.portQuic;
    };

    # Ensure AdGuard Home data directory exists
    systemd.tmpfiles.rules = [
      "d /var/lib/AdGuardHome 0750 adguardhome adguardhome -"
    ];

    # User and group for AdGuard Home
    users.users.adguardhome = {
      isSystemUser = true;
      group = "adguardhome";
      description = "AdGuard Home daemon user";
    };

    users.groups.adguardhome = { };
  };
}
