{ lib, config, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.matomo;
in
{
  options.campground.services.matomo = with types; {
    enable = mkBoolOpt false "Enable Matomo;";
    rootDomain = mkOpt str "lan.aicampground.com" "Root domain to use for Matomo";
  };

  config = mkIf cfg.enable {
    campground.services.mysql = {
      enable = true;
      databases = [
        {
          name = "matomo";
          user = "matomo";
        }
      ];
    };

    services.matomo = {
      enable = true;
      hostname = cfg.rootDomain;
      nginx = {
        serverAliases = [
          "matomo.${cfg.rootDomain}"
          "stats.${cfg.rootDomain}"
        ];
        serverName = "matomo.${cfg.rootDomain}";
        listen = [
          {
            addr = "0.0.0.0";
            port = 16969; # Change this to your desired port
          }
        ];
        enableACME = false;
        forceSSL = false;

      };

    };

  };
}
