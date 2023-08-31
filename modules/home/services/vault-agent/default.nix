{ lib, config, pkgs, inputs, ... }:

let
  cfg = config.campground.services.vault-agent;

  secret-files-root = "/tmp/detsys-vault";
  environment-files-root = "/run/keys/environment";

  create-environment-files-submodule = service-name: lib.types.submodule ({ name, ... }: {
    options = {
      text = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "An inline template for Vault to template.";
      };
      source = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "The file with environment variables for Vault to template.";
      };
      path = lib.mkOption {
        readOnly = true;
        type = lib.types.str;
        description = "The path to the environment file.";
        default = "${environment-files-root}/${service-name}/${name}.EnvFile";
      };
    };
  });

  secret-files-submodule = lib.types.submodule ({ name, ... }: {
    options = {
      text = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "An inline template for Vault to template.";
      };
      source = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "The file for Vault to template.";
      };
      permissions = lib.mkOption {
        type = lib.types.str;
        default = "0400";
        description = "The octal mode of this file.";
      };
      change-action = lib.mkOption {
        type = lib.types.nullOr (lib.types.enum [ "restart" "stop" "none" ]);
        default = null;
        description = "The action to take when secrets change.";
      };
      path = lib.mkOption {
        readOnly = true;
        type = lib.types.str;
        description = "The path to the secret file.";
        default = "${secret-files-root}/${name}";
      };
    };
  });

  services-submodule = lib.types.submodule ({ name, config, ... }: {
    options = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to enable Vault Agent for this service.";
      };
      settings = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = "Vault Agent configuration.";
      };
      secrets = {
        environment = {
          force = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Whether or not to force the use of Vault Agent's environment files.";
          };
          change-action = lib.mkOption {
            type = lib.types.enum [ "restart" "stop" "none" ];
            default = "restart";
            description = "The action to take when secrets change.";
          };
          templates = lib.mkOption {
            type = lib.types.attrsOf (create-environment-files-submodule name);
            default = { };
            description = "Environment variable files for Vault to template.";
          };
          template = lib.mkOption {
            type = lib.types.nullOr (lib.types.either lib.types.path lib.types.str);
            default = null;
            description = "An environment variable template.";
          };
          paths = lib.mkOption {
            readOnly = true;
            type = lib.types.listOf lib.types.str;
            description = "Paths to all of the environment files";
            default =
              if config.secrets.environment.template != null then
                [ "${environment-files-root}/${name}/EnvFile" ]
              else
                (
                  lib.mapAttrsToList
                    (template-name: value: value.path)
                    config.secrets.environment.templates
                );
          };
        };

        file = {
          change-action = lib.mkOption {
            type = lib.types.enum [ "restart" "stop" "none" ];
            default = "restart";
            description = "The action to take when secrets change.";
          };
          files = lib.mkOption {
            description = "Secret files to template.";
            default = { };
            type = lib.types.attrsOf secret-files-submodule;
          };
        };
      };
    };
  });

in {
  options.campground.services.vault-agent = {
    enable = lib.mkEnableOption "Vault Agent";
    settings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Default Vault Agent configuration.";
    };
    services = lib.mkOption {
      description = "Services to install Vault Agent into.";
      default = { };
      type = lib.types.attrsOf services-submodule;
    };
  };

  config = lib.mkIf cfg.enable {
    home.activation.vaultAgent = inputs.home-manager.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      # Your activation script to set up Vault Agent with Home Manager
    '';
  };
}

