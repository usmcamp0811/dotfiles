{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.searx;
in
{
  options.campground.services.searx = with types; {
    enable = mkBoolOpt false "Enable an Searx;";
    port = mkOpt int 8080 "Port to Host the searx server on.";
  };

  config = mkIf cfg.enable {
    services = {
      searx = {
        enable = true;
        settings = {
          server.port = cfg.port;
          server.bind_address = "0.0.0.0";
          server.secret_key = "@SEARX_SECRET_KEY@";
          engines = nixpkgs.lib.singleton
            {
              name = "wolframalpha";
              shortcut = "wa";
              api_key = "@WOLFRAM_API_KEY@";
              engine = "wolframalpha_api";
            };
        };
      };
    };
  };
}
