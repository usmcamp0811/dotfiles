{ options, config, pkgs, lib, ... }:

with lib;
with lib.internal;
let
  cfg = config.system.user-secrets;
in
{
  options.system.user-secrets = with types; {
    enable = mkBoolOpt false "Whether or not to enable secret-service.";

    users = mkOption {
      type = with types; attrsOf (listOf str);
      default = {};
      description = "The list of users and their secrets.";
    };
  };

  config = mkIf cfg.enable {
    campground.services.vault-agent.services = lib.mkMerge (lib.mapAttrsToList (user: secrets: {
      name = "secret-service-${user}";
      value = {
        enable = true;
        settings = {
          vault.address = config.campground.services.vault-agent.settings.vault.address;
          auto_auth = {
            method = [{
              type = "approle";
              config = {
                role_id_file_path = config.campground.services.vault-agent.settings.vault.role-id;
                secret_id_file_path = config.campground.services.vault-agent.settings.vault.secret-id;
                remove_secret_id_file_after_reading = false;
              };
            }];
          };
        };
        secrets = {
          file = {
            files = lib.mkMerge (lib.mapAttrsToList (secret: _: {
              name = secret;
              value = {
                text = ''
                  {{ with secret "secret/campground/users/${user}/${secret}" }}
                  {{ .Data.${secret} }}
                  {{ end }}
                '';
                permissions = "0400";
                change-action = "restart";
              };
            }) secrets);
          };
        };
      };
    }) cfg.users);
  };
}

