{ options, config, pkgs, lib, systems, name, format, inputs, ... }:

with lib;
with lib.internal;
let
  cfg = config.campground.services.my-service;
in
{
  options.campground.services.my-service = with types; {
    enable = mkBoolOpt false "Whether or not to enable my-service.";
  };

  config = mkIf cfg.enable {
    systemd.services."my-service" = {
      description = "My Service";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.bash}/bin/bash -c 'for i in {1..5}; do echo hello; sleep 1; done'";
        Type = "oneshot";
        # EnvironmentFile = "/secret-tst";
      };
    };
  };
}

