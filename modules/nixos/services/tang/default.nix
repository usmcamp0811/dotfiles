{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.tang;
in
{
  options.campground.services.tang = with types; {
    enable = mkBoolOpt false "Enable an Tang;";
    port = mkOpt int 1234 "Port to Host the tang server on.";
  };

  config = mkIf cfg.enable {
    virtualisation.oci-containers.containers = {
      tang = {
        image = "padhihomelab/tang";
        volumes = ["tangdb:/db"];
        ports = ["${cfg.port}:8080"]; 
      };
    }; 
  };
}
