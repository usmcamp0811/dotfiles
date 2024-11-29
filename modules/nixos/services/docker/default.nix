{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.services.docker;
in {
  options.campground.services.docker = with types; {
    enable = mkBoolOpt false "Enable Docker;";
  };

  config = mkIf cfg.enable {
    virtualisation.docker.enable = true;
    campground.system.aliases = {
      dkill =
        "${pkgs.docker}/bin/docker stop $1 && ${pkgs.docker}/bin/docker rm $1";
    };
    environment.systemPackages = with pkgs; [ docker-compose ];
  };
}
