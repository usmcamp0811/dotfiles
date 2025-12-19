{
  options,
  config,
  lib,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.onepassword-secrets;
in {
  options.fmf.services.onepassword-secrets = with types; {
    enable = mkBoolOpt false "Enable 1Password secrets integration via OpNix";

    tokenFile = mkOption {
      type = path;
      default = "/etc/opnix-token";
      description = ''
        Path containing the 1Password service account token.
        File should be readable by root and opnix group (640 permissions recommended).
      '';
    };

    configFiles = mkOption {
      type = listOf path;
      default = [];
      description = ''
        List of JSON configuration files containing secrets.
        Supports multiple files for organization.
      '';
    };

    outputDir = mkOption {
      type = str;
      default = "/var/lib/opnix/secrets";
      description = ''
        Base directory where secrets are stored when not specified individually.
      '';
    };

    users = mkOption {
      type = listOf str;
      default = [];
      description = "Users granted secret access via group membership";
    };

    secrets = mkOption {
      type = attrsOf attrs;
      default = {};
      description = ''
        Declarative secrets configuration.
        See OpNix documentation for full secret options.
      '';
      example = literalExpression ''
        {
          database-password = {
            reference = "op://Homelab/Database/password";
            owner = "postgres";
            group = "postgres";
            mode = "0400";
            services = [ "postgresql" ];
          };
        }
      '';
    };

    pathTemplate = mkOption {
      type = str;
      default = "";
      description = ''
        Template for generating secret paths with variable substitution.
        Available variables: {service}, {environment}, {name}, plus custom variables.
      '';
      example = "/var/secrets/{environment}/{service}/{name}";
    };

    defaults = mkOption {
      type = attrsOf str;
      default = {};
      description = "Default values for template variables";
      example = literalExpression ''
        {
          environment = "production";
        }
      '';
    };

    systemdIntegration = mkOption {
      type = attrs;
      default = {};
      description = ''
        Advanced systemd integration configuration.
        See OpNix documentation for full systemd integration options.
      '';
    };
  };

  config = mkIf cfg.enable {
    # Pass configuration through to the upstream OpNix module
    services.onepassword-secrets = {
      enable = true;
      tokenFile = cfg.tokenFile;
      configFiles = cfg.configFiles;
      outputDir = cfg.outputDir;
      users = cfg.users;
      secrets = cfg.secrets;
      pathTemplate = mkIf (cfg.pathTemplate != "") cfg.pathTemplate;
      defaults = mkIf (cfg.defaults != {}) cfg.defaults;
      systemdIntegration = mkIf (cfg.systemdIntegration != {}) cfg.systemdIntegration;
    };
  };
}
