{ options, config, pkgs, lib, ... }:

with lib;
with lib.internal;
let
  cfg = config.campground.services.user-secrets;
in
{
  options.campground.services.user-secrets = with types; {
    enable = mkBoolOpt false "Whether or not to enable secret-service.";
    role-id = mkOpt str config.campground.services.vault-agent.settings.vault.role-id "Absolute path to the Vault role-id";
    secret-id = mkOpt str config.campground.services.vault-agent.settings.vault.secret-id "Absolute path to the Vault secret-id";
    vault-path = mkOpt str "secret/campground/wifi" "The Vault path to the KV containing the Wifi Secrets.";
    vault-address = mkOption {
      type = str;
      default = config.campground.services.vault-agent.settings.vault.address;
      description = "The address of your Vault";
    };
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
                role_id_file_path = cfg.role-id;
                secret_id_file_path = cfg.secret-id;
                remove_secret_id_file_after_reading = false;
              };
            }];
          };
        };
        secrets = {
          file = {
            files = lib.mkMerge (lib.mapAttrsToList (secret: _: {
              name = "${user}-${secret}";
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

    systemd.services = lib.mkMerge (lib.mapAttrsToList (user: secrets: {
      name = "secret-service-${user}";
      value = {
        description = "Copy Secret Service for ${user}";
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          ExecStart = "${pkgs.bash}/bin/bash -c 'mkdir -p /var/lib/vault/users/${user}; chown ${user} /var/lib/vault/users/${user}; chmod 0700 /var/lib/vault/users/${user}; for secret in ${lib.concatStringsSep " " secrets}; do cp /tmp/detsys-vault/${user}-$secret /var/lib/vault/users/${user}/$secret; chown ${user} /var/lib/vault/users/${user}/$secret; chmod 0400 /var/lib/vault/users/${user}/$secret; done'";

          Type = "oneshot";
        };
      };
    }) cfg.users);
  };
}

