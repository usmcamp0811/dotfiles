{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.secret-service;
in {
  options.fmf.services.secret-service = with types; {
    enable = mkBoolOpt false "Whether or not to enable secret-service.";
  };

  config = mkIf cfg.enable {
    systemd.services."secret-service" = {
      description = "My Example Secret Service";
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        # ExecStart = "${pkgs.bash}/bin/bash -c 'for i in {1..5}; do echo $YANKEE_WHITE; sleep 1; done'";
        ExecStart = "${pkgs.bash}/bin/bash -c 'for i in {1..5}; do echo FROM A FILE: $(cat /tmp/detsys-vault/my-secret-file) FROM ENV: $YANKEE_WHITE; sleep 1; done'";
        Type = "oneshot";
      };
    };
  };
}
