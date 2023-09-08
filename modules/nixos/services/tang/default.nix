{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.tang;
in
{
  options.campground.services.tang = with types; {
    enable = mkBoolOpt false "Enable an Nginx Proxy;";
    port = mkOpt int 8080 "Port to Host the NGINX porxy on.";
  };

  config = mkIf cfg.enable {
    virtualisation.oci-containers.containers = {
      tang = {
        image = "padhihomelab/tang";
        volumes = ["tangdb:/db"];
        ports = ["1234:8080"]; # expose on 9090
      };
    }; 
  };
}
