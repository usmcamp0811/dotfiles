{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.entrypoint;
in {
  options.fmf.services.entrypoint = with types; {
    enable = mkBoolOpt false "Enable Docker;";
    user = mkOpt str "root" "User to run the container";
    group = mkOpt str "root" "Group of the user running the container";
    script = mkOpt str "${pkgs.zsh}/bin/zsh" "Path to the entrypoint script";
    cmd = mkOpt str "" "The CMD to run in the Docker container";
  };

  config = mkIf cfg.enable {
    users.users."${cfg.user}" = {
      isSystemUser = true;
      group = "${cfg.group}";
    };

    users.groups."${cfg.group}" = {};
    systemd.user.services.docker-entrypoint = {
      description = "Entrypoint Systemd Service for use in Docker Images";
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = "${
          pkgs.writeScript "entrypoint" ''
            #!/bin/sh
            echo "Welcome to the Campground Container."
            /bin/sh ${cfg.script} ${cfg.cmd}
          ''
        }/bin/entrypoint";
      };
      wantedBy = ["default.target"];
    };
  };
}
