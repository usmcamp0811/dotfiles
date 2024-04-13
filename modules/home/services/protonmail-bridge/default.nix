{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.services.protonmail-bridge;
in {
  options.campground.services.protonmail-bridge = with types; {
    enable = mkBoolOpt false "Whether or not to enable protonmail-bridge.";
    pass = mkOption {
      type = types.nullOr types.package;
      default = pkgs.pass-wayland;
      description = "Which Password manager to use";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [pkgs.protonmail-bridge cfg.pass];

    services.pass-secret-service.enable = true;
    systemd.user.services.protonmail = {
      Unit = {
        Description = "Protonmail Bridge";
        Requires = ["pass-secret-service.service" "gpg-agent.socket"];
      };
      Service = {
        Restart = "always";
        ExecStart = "${pkgs.protonmail-bridge}/bin/protonmail-bridge --noninteractive";
        Environment = ["PATH=${cfg.pass}/bin"];
      };
      Install = {WantedBy = ["default.target"];};
    };
  };
}
