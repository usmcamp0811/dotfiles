{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.dnscrypt-proxy;

  # OISD blocklist for dnscrypt-proxy
  # Fetched at build time instead of as a flake input to avoid breaking consumers
  # when the nightly blocklist changes
  oisd-blocklist = pkgs.fetchurl {
    url = "https://big.oisd.nl/domainswild";
    # This hash will need to be updated periodically, but won't break consumers
    # Run: nix-prefetch-url https://big.oisd.nl/domainswild
    # Last updated: 2026-06-26
    sha256 = "0chhxcplmywp8a1ldf675ks2afvdwsgyvvfz7sck1bzw8zhi8ayp";
  };

  blocklist_base = builtins.readFile oisd-blocklist;
  blocklist_txt = pkgs.writeText "blocklist.txt" ''
    ${cfg.extraBlocklist}
    ${blocklist_base}
  '';

  # dnscrypt-proxy state directory
  StateDirName = "dnscrypt-proxy";
  StatePath = "/var/lib/${StateDirName}";
in {
  options.fmf.services.dnscrypt-proxy = with types; {
    enable =
      mkBoolOpt false
      "Enable dnscrypt-proxy with ODoH (Oblivious DNS over HTTPS)";

    listenAddresses =
      mkOpt (listOf str) ["127.0.0.1:5353" "[::1]:5353"]
      "Local addresses and ports to listen on";

    serverNames =
      mkOpt (listOf str) ["odoh-cloudflare" "odoh-snowstorm"]
      "ODoH servers to use";

    odohServers = mkBoolOpt true "Enable Oblivious DoH servers";
    dnscryptServers = mkBoolOpt true "Enable DNSCrypt servers";

    hasIPv6Internet =
      mkBoolOpt true "Whether the system has IPv6 internet connectivity";

    requireDNSSEC = mkBoolOpt true "Require DNSSEC validation";
    requireNolog = mkBoolOpt false "Only use servers that don't log queries";
    requireNofilter =
      mkBoolOpt false "Only use servers that don't filter content";

    extraBlocklist =
      mkOpt str "" "Extra domains to block (in addition to OISD list)";

    anonymizedDns = {
      enable = mkBoolOpt true "Enable anonymized DNS (ODoH routing)";

      skipIncompatible =
        mkBoolOpt true "Skip servers that don't support anonymization";

      routes = mkOpt (listOf attrs) [
        {
          server_name = "odoh-snowstorm";
          via = ["odohrelay-crypto-sx"];
        }
        {
          server_name = "odoh-cloudflare";
          via = ["odohrelay-crypto-sx"];
        }
      ] "ODoH routing configuration (server -> relay mapping)";
    };

    extraSettings =
      mkOpt attrs {}
      "Additional settings to merge into dnscrypt-proxy configuration";
  };

  config = mkIf cfg.enable {
    services.dnscrypt-proxy2 = {
      enable = true;
      settings = mkMerge [
        {
          listen_addresses = cfg.listenAddresses;
          server_names = cfg.serverNames;

          # Source configurations for public resolvers, relays, and ODoH servers
          sources.public-resolvers = {
            urls = [
              "https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v3/public-resolvers.md"
              "https://download.dnscrypt.info/resolvers-list/v3/public-resolvers.md"
            ];
            minisign_key = "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3";
            cache_file = "${StatePath}/public-resolvers.md";
          };

          sources.relays = {
            urls = [
              "https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v3/relays.md"
              "https://download.dnscrypt.info/resolvers-list/v3/relays.md"
            ];
            cache_file = "${StatePath}/relays.md";
            minisign_key = "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3";
          };

          sources.odoh-servers = {
            urls = [
              "https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v3/odoh-servers.md"
              "https://download.dnscrypt.info/resolvers-list/v3/odoh-servers.md"
            ];
            cache_file = "${StatePath}/odoh-servers.md";
            minisign_key = "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3";
          };

          sources.odoh-relays = {
            urls = [
              "https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v3/odoh-relays.md"
              "https://download.dnscrypt.info/resolvers-list/v3/odoh-relays.md"
            ];
            cache_file = "${StatePath}/odoh-relays.md";
            minisign_key = "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3";
          };

          # Anonymized DNS (ODoH) configuration
          anonymized_dns = mkIf cfg.anonymizedDns.enable {
            skip_incompatible = cfg.anonymizedDns.skipIncompatible;
            routes = cfg.anonymizedDns.routes;
          };

          # Server type preferences
          ipv6_servers = cfg.hasIPv6Internet;
          block_ipv6 = !cfg.hasIPv6Internet;
          odoh_servers = cfg.odohServers;
          dnscrypt_servers = cfg.dnscryptServers;

          # Security and privacy settings
          require_dnssec = cfg.requireDNSSEC;
          require_nolog = cfg.requireNolog;
          require_nofilter = cfg.requireNofilter;

          # OISD blocklist integration
          blocked_names.blocked_names_file = toString blocklist_txt;
        }

        cfg.extraSettings
      ];
    };

    # Ensure state directory exists with correct permissions
    systemd.services.dnscrypt-proxy2.serviceConfig.StateDirectory =
      StateDirName;

    networking.firewall.allowedTCPPorts = [5353];
    networking.firewall.allowedUDPPorts = [5353];
  };
}
