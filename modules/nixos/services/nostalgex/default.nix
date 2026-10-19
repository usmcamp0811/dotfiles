{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.nostalgex;

  # Runtime config the tuner fetches from /config.json. Upstream's image writes
  # the same keys at container start from NOSTALGEX_ENRICHMENT
  # (docker/40-config.sh); here it is rendered at build time. The tuner fails
  # closed: anything but `"enrichment": true` means no Supabase or relay requests.
  configDir = pkgs.writeTextDir "config.json" (builtins.toJSON {
    tunerVersion = cfg.package.version or "dev";
    musicLookups = false;
    inherit (cfg) enrichment;
  });

  # Copied from upstream's docker/nginx.conf. There is no HSTS on purpose: this
  # is plain http on a home network. The CSP allows http: and https: media
  # servers because the point is reaching a LAN Jellyfin or Emby.
  contentSecurityPolicy = concatStringsSep "; " [
    "default-src 'self'"
    "script-src 'self' 'unsafe-inline'"
    "style-src 'self' 'unsafe-inline'"
    "font-src 'self' data:"
    "img-src 'self' data: blob: http: https:"
    "media-src 'self' blob: data: http: https:"
    "connect-src 'self' http: https: ws: wss:"
    "worker-src 'self' blob:"
    "object-src 'none'"
    "base-uri 'self'"
    "frame-ancestors 'self'"
    "form-action 'self'"
  ];
in {
  options.fmf.services.nostalgex = with types; {
    enable = mkBoolOpt false "Enable the Nostalgex self-hosted web tuner (static files served by Nginx).";
    package = mkOpt package pkgs.fmf.nostalgex "Nostalgex package to serve. Override it to build with your own Supabase project (see the README).";
    port = mkOpt port 8080 "Port to listen on.";
    listenAddress = mkOpt str "0.0.0.0" "Address to listen on.";
    domain = mkOpt str "_" "Nginx server_name. The default, \"_\", answers on any address or hostname.";
    openFirewall = mkBoolOpt false "Open the tuner port in the firewall.";
    enrichment = mkBoolOpt false ''
      Allow the tuner to fetch TMDB/IMDb metadata (keywords, studios, ratings) that
      about nine channels need. Only TMDB and IMDb ids leave the browser, to the shared
      Supabase cache and the nostalgex.app relay. It does nothing unless the package
      was built with a Supabase URL and anon key. Upstream's image defaults this to on;
      this module defaults to off so nothing leaves the network unless you ask.
    '';
  };

  config = mkIf cfg.enable {
    warnings = optional (cfg.enrichment && !(cfg.package.passthru.enrichmentConfigured or true)) ''
      fmf.services.nostalgex.enrichment is enabled, but the package was built without a
      Supabase URL and anon key, so the tuner will make no enrichment requests. Build it with
      `pkgs.fmf.nostalgex.override { supabaseUrl = "..."; supabaseAnonKey = "..."; }`.
    '';

    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [cfg.port];

    services.nginx = {
      enable = true;
      virtualHosts.${cfg.domain} = {
        listen = [
          {
            addr = cfg.listenAddress;
            port = cfg.port;
          }
        ];
        root = "${cfg.package}/share/nostalgex";
        extraConfig = ''
          # nginx has no type for .cjs, and with nosniff a wrong type blocks
          # scripts/nostalgex-channel-filter.cjs, which breaks the library load.
          # A `types` block at server level replaces the inherited map, and the
          # defaults file is itself a `types` block, so include it here and add a
          # second block beside it (blocks at the same level merge).
          include ${config.services.nginx.defaultMimeTypes};
          types {
            text/javascript cjs;
          }

          server_tokens off;
          # Relative Location headers, so redirects keep whatever host and port
          # the browser used (a mapped port, a LAN name, a reverse proxy).
          absolute_redirect off;
          charset utf-8;
          charset_types text/css application/javascript application/json;

          gzip on;
          gzip_comp_level 5;
          gzip_min_length 1024;
          gzip_types text/css application/javascript application/json image/svg+xml;

          add_header X-Content-Type-Options "nosniff" always;
          add_header X-Frame-Options "SAMEORIGIN" always;
          add_header Referrer-Policy "no-referrer" always;
          add_header Permissions-Policy "camera=(), microphone=(), geolocation=()" always;
          add_header Content-Security-Policy "${contentSecurityPolicy}" always;
        '';

        locations = {
          # Pages, channels.json and the helper scripts change with every release.
          "/" = {
            tryFiles = "$uri $uri.html $uri/ =404";
            extraConfig = "expires -1;";
          };
          # Vite's hashed bundle names.
          "/assets/".extraConfig = "expires 1y;";
          # hls.js and qrcodejs load with a ?v=<version> query; fonts rarely move.
          "/vendor/".extraConfig = "expires 7d;";
          # Overrides the build's default config.json with the module's settings.
          "= /config.json" = {
            root = "${configDir}";
            extraConfig = "expires -1;";
          };
          "= /healthz".extraConfig = ''
            access_log off;
            default_type text/plain;
            return 200 "ok\n";
          '';
        };
      };
    };
  };
}
