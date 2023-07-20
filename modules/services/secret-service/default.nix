{ options, config, pkgs, lib, systems, name, format, inputs, ... }:

with lib;
with lib.internal;
let
  cfg = config.campground.services.secret-service;
in
{
  options.campground.services.secret-service = with types; {
    enable = mkBoolOpt false "Whether or not to enable secret-service.";
  };

  config = mkIf cfg.enable {
    systemd.services."secret-service" = {
      description = "My Example Secret Service";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.bash}/bin/bash -c 'for i in {1..5}; do echo $YANKEE_WHITE; sleep 1; done'";
        Type = "oneshot";
      };
    };
  };
}

