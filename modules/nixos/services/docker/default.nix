{ lib, config, pkgs, ... }:
with lib;
with lib.fmf;
let cfg = config.fmf.services.docker;
in {
  options.fmf.services.docker = with types; {
    enable = mkBoolOpt false "Enable Docker;";
  };

  config = mkIf cfg.enable {
    virtualisation.docker.enable = true;
    fmf.system.aliases = {
      dkill =
        "${pkgs.docker}/bin/docker stop $1 && ${pkgs.docker}/bin/docker rm $1";
    };
    environment.systemPackages = with pkgs; [ docker-compose ];
  };
}
