{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.services.file-share;
in {
  options.campground.services.file-share = with types; {
    enable = mkBoolOpt false "Enable file-share;";
    port = mkOpt int 8380 "Port to listen on";
  };

  config =
    mkIf cfg.enable { 
    services.nginx = {
      enable = true;
      virtualHosts."localhost" = {
        listen = [{ addr = "0.0.0.0"; port = cfg.port; }];
        root = "/export/share";
        locations."/".extraConfig = ''
          autoindex on;
        '';
      };
  };
}

