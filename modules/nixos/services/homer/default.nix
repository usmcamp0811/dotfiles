{ lib, config, pkgs, ... }:
with lib;
with lib.fmf;
let
  cfg = config.fmf.services.homer;

  yaml-format = pkgs.formats.yaml { };
  settings-yaml = yaml-format.generate "config.yml" cfg.settings;

  settings-path = if cfg.settings-path != null then
    cfg.settings-path
  else
    builtins.toString settings-yaml;
in {
  options.fmf.services.homer = {
    enable = mkEnableOption "Homer";

    package = mkOpt types.package pkgs.fmf.homer
      "The package of Homer assets to use.";

    settings =
      mkOpt yaml-format.type { } "Configuration for Homer's config.yml file.";
    settings-path = mkOpt (types.nullOr types.path) null
      "A replacement for the generated config.yml file.";

    host = mkOpt (types.nullOr types.str) null "The host to serve Homer on.";

    listen = lib.mkOption {
      type = lib.types.nullOr (lib.types.attrsOf lib.types.str);
      default = null;
      description = ''
        Nginx listen config for the virtual host. Example:
        `{ addr = "0.0.0.0"; port = "8080"; }`
      '';
    };

    nginx = {
      forceSSL = mkOption {
        type = types.bool;
        default = false;
        description = "Whether or not to force the use of SSL.";
      };
    };

    acme = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description =
          "Whether or not to automatically fetch and configure SSL certs.";
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.host != null;
        message = "fmf.services.homer.host must be set.";
      }
      {
        assertion = cfg.settings-path != null -> cfg.settings == { };
        message =
          "fmf.services.homer.settings and fmf.services.homer.settings-path are mutually exclusive.";
      }
      {
        assertion = cfg.nginx.forceSSL -> cfg.acme.enable;
        message =
          "fmf.services.homer.nginx.forceSSL requires setting fmf.services.homer.acme.enable to true.";
      }
    ];

    services.nginx = {
      enable = true;

      virtualHosts."${cfg.host}" = {
        listen = lib.optional (cfg.listen != null) cfg.listen;

        enableACME = cfg.acme.enable;
        forceSSL = cfg.nginx.forceSSL;

        locations."/" = { root = "${cfg.package}/share/homer"; };

        locations."= /assets/config.yml" = { alias = settings-path; };
      };
    };

    networking.firewall.allowedTCPPorts = lib.optional (cfg.listen != null) (lib.toInt cfg.listen.port);
  };
}
