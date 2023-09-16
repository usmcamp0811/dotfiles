{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.docker;
in
{
  options.campground.services.docker = with types; {
    enable = mkBoolOpt false "Enable Docker;";
  };

  config = mkIf cfg.enable {
    users.users.jupyter = {
      isSystemUser = true;
      group = "jupyter";
    };

    users.groups.jupyter = {};

    services.jupyter = {
      enable = true;
      port = 8888;
      notebookDir = "/path/to/notebooks";
      user = "jupyter";
      group = "jupyter";
      environment = pkgs.python3.withPackages (ps: with ps; [ jupyterlab ]);
    };

    systemd.services.jupyter = {
      description = "Jupyter Lab";
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.python3Packages.jupyter}/bin/jupyter lab --no-browser --port=${toString config.services.jupyter.port} --notebook-dir=${config.services.jupyter.notebookDir}";
        User = config.services.jupyter.user;
        Group = config.services.jupyter.group;
        Restart = "always";
      };
      environment = config.services.jupyter.environment;
    };

  };
}
