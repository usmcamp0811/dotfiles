{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.jupyter;
in
{
  options.campground.services.jupyter = with types; {
    enable = mkBoolOpt false "Enable Docker;";
  };

  config = mkIf cfg.enable {
    users.users.jupyter = {
      isSystemUser = true;
      group = "jupyter";
    };

    users.groups.jupyter = {};

    systemd.services.jupyterlab = {
      description = "Jupyter Lab";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.jupyterlab}/bin/jupyter-lab";
      };
    };
  };
}
