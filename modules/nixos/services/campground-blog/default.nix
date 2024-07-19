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
        listen = [ cfg.port ];
        root = "/var/www/myblog";
        index = "index.html";
        locations."/" = { tryFiles = "$uri $uri/ =404"; };
      };
    };
  };
}
