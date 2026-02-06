{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.netdata;
in {
  options.fmf.services.netdata = {
    enable = mkEnableOption "Netdata network and system monitoring";

    package = mkOpt types.package pkgs.netdata "The Netdata package to use.";

    port = mkOpt types.port 19999 "The port to run Netdata on.";

    bind = mkOpt types.str "0.0.0.0" "The address to bind Netdata to.";

    config = mkOption {
      type = types.attrs;
      default = {};
      description = "Netdata configuration as an attribute set.";
      example = literalExpression ''
        {
          global = {
            "default port" = "19999";
            "bind to" = "0.0.0.0";
          };
        }
      '';
    };

    configText = mkOption {
      type = types.nullOr types.lines;
      default = null;
      description = "Raw Netdata configuration text. Overrides config option if set.";
    };

    python = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to enable Python plugins.";
      };

      extraPackages = mkOption {
        type = types.functionTo (types.listOf types.package);
        default = ps: [];
        description = "Extra Python packages to make available to Netdata plugins.";
        example = literalExpression "ps: [ ps.requests ps.pyyaml ]";
      };
    };

    extraPlugins = mkOption {
      type = types.listOf types.package;
      default = [];
      description = "Extra Netdata plugins to install.";
    };
  };

  config = mkIf cfg.enable {
    services.netdata = {
      enable = true;
      package = cfg.package;

      config = mkMerge [
        {
          global = {
            "default port" = toString cfg.port;
            "bind to" = cfg.bind;
          };
        }
        cfg.config
      ];

      configText = mkIf (cfg.configText != null) cfg.configText;

      python = {
        enable = cfg.python.enable;
        extraPackages = cfg.python.extraPackages;
      };
    };

    # Open firewall port
    networking.firewall.allowedTCPPorts = [ cfg.port ];

    # Add extra plugins to the package if specified
    nixpkgs.overlays = mkIf (cfg.extraPlugins != []) [
      (final: prev: {
        netdata = prev.netdata.overrideAttrs (old: {
          buildInputs = (old.buildInputs or []) ++ cfg.extraPlugins;
        });
      })
    ];
  };
}
