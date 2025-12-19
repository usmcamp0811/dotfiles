{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.jupyter;
in {
  options.fmf.services.jupyter = with types; {
    enable = mkBoolOpt false "Enable Docker;";
    user = mkOpt str "jupyter" "The user name to run Jupyter Lab as..";
    group = mkOpt str "jupyter" "The group name to run Jupyter Lab as..";
    ip = mkOpt str "0.0.0.0" "The IP to expose Jupyter on.";
    workDir = mkOpt str "/code" "Working dir to start Jupyter in.";
  };

  config = mkIf cfg.enable {
    users.users."${cfg.user}" = {
      isSystemUser = true;
      group = cfg.group;
    };

    users.groups."${cfg.group}" = {};

    environment.systemPackages = with pkgs; [jupyterlab];

    systemd.tmpfiles.rules = ["d ${cfg.workDir} 0755 ${cfg.user} ${cfg.group} -"];

    systemd.services.jupyterlab = {
      description = "Jupyter Lab";
      wantedBy = ["multi-user.target"];
      after = ["network.target"];
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.workDir;
        ExecStart = "/bin/sh -c '${pkgs.jupyterlab}/bin/jupyter-lab --ip=${cfg.ip}'";
      };
    };
  };
}
