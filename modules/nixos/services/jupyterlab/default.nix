{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.jupyter;
in
{
  options.campground.services.jupyter = with types; {
    enable = mkBoolOpt false "Enable Docker;";
    user = mkOpt str "jupyter" "The user name to run Jupyter Lab as..";
    group = mkOpt str "jupyter" "The group name to run Jupyter Lab as..";
    ip = mkOpt str "0.0.0.0" "The IP to expose Jupyter on.";
    workDir = mkOpt str "/code" "Working dir to start Jupyter in.";
    password = mkOpt str "65cf8cd353cae2b48a8480cc49cd2e7dabb1bbb3" "Jupyter Lab Hashed Password <your_password_here>.";
  };

  config = mkIf cfg.enable {
    users.users."${cfg.user}" = {
      isSystemUser = true;
      group = cfg.group;
    };

    users.groups."${cfg.group}" = {};

    environment.systemPackages = with pkgs; [
      jupyterlab
    ];

    systemd.services.jupyterlab = {
      description = "Jupyter Lab";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = ${cfg.workDir};
        ExecStart = "/bin/sh -c '${pkgs.jupyter-lab}/bin/jupyter-lab --ip=${cfg.ip} --NotebookApp.password=\'${cfg.password}\''";
      };
    };
  };
}
