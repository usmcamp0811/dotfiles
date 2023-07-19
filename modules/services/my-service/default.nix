{ options, config, pkgs, lib, systems, name, format, inputs, ... }:

with lib;
with lib.internal;
let
  cfg = config.campground.services.openssh;
in
{
  config = mkIf cfg.enable {

    my-service = {
      description = "My Service";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.bash}/bin/bash -c 'for i in {1..5}; do echo hello; sleep 1; done'";
        Type = "oneshot";
        EnvironmentFile = "/secret-tst";
      };
    };

  };
}
