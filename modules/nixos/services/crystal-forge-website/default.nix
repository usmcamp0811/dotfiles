{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.services.crystal-forge-website;
in {
  options.campground.services.crystal-forge-website = with types; {
    enable = mkBoolOpt false "Enable serving the Nix Slidev deck via Nginx.";
    port = mkOpt int 4399 "Port to listen on.";
    domain = mkOpt str "crystal-forge.us" "Domain name to serve slides from.";
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
        root = "${pkgs.cf-slides}";
        extraConfig = ''
          # Include default MIME types
          include ${pkgs.nginx}/conf/mime.types;

          # Explicitly set MIME types for JavaScript modules
          location ~* \.(js|mjs)$ {
            add_header Content-Type "application/javascript; charset=utf-8";
            try_files $uri =404;
          }

          # Main location block
          location / {
            try_files $uri $uri/ /index.html;
          }
        '';
      };
    };
  };
}
