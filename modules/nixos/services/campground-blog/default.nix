{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.services.campground-blog;
in {
  options.campground.services.campground-blog = with types; {
    enable = mkBoolOpt false "Enable the Campground Blog";
    port = mkOpt int 28345 "Port to host the Blog on";
    domain = mkOpt str "blog.aicampground.com" "The Blog Domain";
  };

  config = mkIf cfg.enable {

    services.nginx = {
      enable = true;
      virtualHosts."${cfg.domain}" = {
        listen = [{
          addr = "0.0.0.0";
          port = cfg.port;
        }];
        root = "${pkgs.campground.blog}/public";
        extraConfig = ''
          location / {
            try_files $uri $uri/ =404;
          }
        '';
      };
    };
  };
}
