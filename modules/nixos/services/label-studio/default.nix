{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  labelStudioSocket = "/run/label-studio.sock";
  cfg = config.campground.services.label-studio;
in
{
  options.campground.services.label-studio = with types; {
    enable = mkBoolOpt false "Enable label-studio;";
    user = lib.mkOption {
      type = lib.types.str;
      default = "label-studio";
      description = "User account under which Label Studio runs.";
    };
    group = lib.mkOption {
      type = lib.types.str;
      default = "label-studio";
      description = "Group under which Label Studio runs.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      label_studio
    ];
    users.users.label-studio = {
      isSystemUser = true;
      group = cfg.group;
    };
    users.groups.label-studio = {};

    systemd.services.label-studio = {
      description = "Label Studio";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.label_studio}/bin/label-studio-gunicorn --bind unix:${labelStudioSocket} -w 4";
        User = cfg.user;
        Group = cfg.group;
        RuntimeDirectory = "label-studio";
        PrivateTmp = true;
      };
    };

    services.nginx = {
      enable = true;
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      virtualHosts."label-studio.example.com" = {
        locations."/".proxyPass = "http://unix:${labelStudioSocket}";
      };
    };

  };
}
