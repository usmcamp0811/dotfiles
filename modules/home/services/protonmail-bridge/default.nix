{ options, config, lib, pkgs, ... }:
with lib;
with lib.fmf;
let cfg = config.fmf.services.protonmail-bridge;
in {
  options.fmf.services.protonmail-bridge = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to enable the Bridge.";
    };

    nonInteractive = mkOption {
      type = types.bool;
      default = true;
      description = "Start Bridge entirely noninteractively";
    };

    pass-package = mkOption {
      type = types.package;
      default = pkgs.pass-wayland;
      description = "Whether to enable the Bridge.";
    };

    logLevel = mkOption {
      type = types.enum [
        "panic"
        "fatal"
        "error"
        "warn"
        "info"
        "debug"
        "debug-client"
        "debug-server"
      ];
      default = "info";
      description = "The log level";
    };

  };
  config = mkIf cfg.enable {
    home.packages = [ pkgs.protonmail-bridge cfg.pass-package ];

    services.pass-secret-service.enable = true;

    systemd.user.services.protonmail-bridge = {
      Unit = {
        Description = "Protonmail Bridge";
        After = [ "network.target" ];
      };
      Service = {
        Restart = "always";
        Environment =
          "PATH=${cfg.pass-package}/bin:${pkgs.protonmail-bridge}/bin:/run/current-system/sw/bin";
        ExecStart =
          "${pkgs.protonmail-bridge}/bin/protonmail-bridge --no-window --log-level ${cfg.logLevel}"
          + optionalString (cfg.nonInteractive) " --noninteractive";
      };

      Install = { WantedBy = [ "default.target" ]; };
    };
  };
}
