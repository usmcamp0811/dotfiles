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
    # users.users.jupyter = {
    #   isSystemUser = true;
    #   group = "jupyter";
    # };
    #
    # users.groups.jupyter = {};

    environment.systemPackages = with pkgs; [
      jupyter-lab
    ];

    # systemd.services.jupyterlab = {
    #   description = "Jupyter Lab";
    #   wantedBy = [ "multi-user.target" ];
    #   after = [ "network.target" ];
    #   serviceConfig = {
    #     Type = "oneshot";
    #     User = "mcamp";
    #     Group = "ldap_user";
    #     Environment = "JUPYTER_CONFIG_DIR=/home/mcamp/.config/jupyter";
    #     WorkingDirectory = "/home/mcamp/code";
    #     ExecStart = "/bin/sh -c 'whoami > /tmp/whoami_jupyterlab.txt && ${pkgs.jupyter-lab}/bin/jupyter-lab --ip 0.0.0.0 --config /home/mcamp/.config/jupyter'";
    #     # Restart = "always";
    #   };
    # };
  };
}
