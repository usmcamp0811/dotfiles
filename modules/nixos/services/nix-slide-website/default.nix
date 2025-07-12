{ lib
, config
, pkgs
, ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.services.nix-slide-website;
in
{
  options.campground.services.nix-slide-website = with types; {
    enable = mkBoolOpt false "Enable serving the Nix Slidev deck via Nginx.";
    port = mkOpt int 4396 "Port to listen on.";
    domain = mkOpt str "nix-slides.aicampground.com" "Domain name to serve slides from.";
  };
  config = mkIf cfg.enable {
    services.nginx = {
      enable = true;
      virtualHosts.${cfg.domain} = {
        listen = [
          {
            addr = "0.0.0.0";
            port = cfg.port;
          }
        ];
        root = "${pkgs.campground.nix-slide-deck}";
        extraConfig = ''
          # Include default MIME types
          include ${pkgs.nginx}/conf/mime.types;

          # Explicitly set MIME types for JavaScript modules
          location ~* \.(js|mjs)$ {
            add_header Content-Type "application/javascript; charset=utf-8";
            add_header Access-Control-Allow-Origin "*";
            add_header Access-Control-Allow-Methods "GET, HEAD, OPTIONS";
            add_header Access-Control-Allow-Headers "Origin, X-Requested-With, Content-Type, Accept, Authorization";
            expires 1h;
            try_files $uri =404;
          }

          # Handle ES modules specifically
          location ~* \.mjs$ {
            add_header Content-Type "application/javascript; charset=utf-8";
            add_header Access-Control-Allow-Origin "*";
            expires 1h;
            try_files $uri =404;
          }

          # Handle CORS preflight requests
          location / {
            if ($request_method = 'OPTIONS') {
              add_header Access-Control-Allow-Origin "*";
              add_header Access-Control-Allow-Methods "GET, HEAD, OPTIONS";
              add_header Access-Control-Allow-Headers "Origin, X-Requested-With, Content-Type, Accept, Authorization";
              add_header Access-Control-Max-Age 86400;
              add_header Content-Length 0;
              add_header Content-Type text/plain;
              return 204;
            }

            # Add CORS headers to all responses
            add_header Access-Control-Allow-Origin "*" always;
            add_header Access-Control-Allow-Methods "GET, HEAD, OPTIONS" always;
            add_header Access-Control-Allow-Headers "Origin, X-Requested-With, Content-Type, Accept, Authorization" always;

            try_files $uri $uri/ =404;
          }
        '';
      };
    };
  };
}
