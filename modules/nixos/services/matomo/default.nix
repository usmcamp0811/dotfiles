{ lib, pkgs, config, ... }:
with lib;
with lib.campground;
let cfg = config.campground.services.matomo;
in {
  options.campground.services.matomo = with types; {
    enable = mkBoolOpt false "Enable Matomo;";
    port = mkOpt int 16969 "Port for matomo";
    rootDomain = mkOpt str "aicampground.com" "Root domain to use for Matomo";
  };

  config = mkIf cfg.enable {
    # TODO: Do better configign of this shit
    campground.services.mysql = {
      enable = true;
      databases = [{
        name = "matomo";
        user = "matomo";
      }];
    };

    services.matomo = {
      enable = true;
      package = pkgs.matomo_5;
      hostname = cfg.rootDomain;
      nginx = {
        serverAliases =
          [ "matomo.${cfg.rootDomain}" "stats.${cfg.rootDomain}" ];
        serverName = "matomo.${cfg.rootDomain}";
        listen = [{
          addr = "0.0.0.0";
          port = cfg.port;
        }];
        enableACME = false;
        forceSSL = false;

      };

    };

  };
}
