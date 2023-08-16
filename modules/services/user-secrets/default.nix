{ options, config, pkgs, lib, ... }:

with lib;
with lib.internal;
let
  cfg = config.campground.services.user-secrets;
in
{
  options.campground.services.user-secrets = with types; {
    enable = mkEnableOption "user-secrets";
    role-id = mkOpt str config.campground.services.vault-agent.settings.vault.role-id "Absolute path to the Vault role-id";
    secret-id = mkOpt str config.campground.services.vault-agent.settings.vault.secret-id "Absolute path to the Vault secret-id";
    vault-path = mkOpt str "secret/campground/users" "The Vault path to the KV containing the User Secrets.";
    vault-address = mkOption {
      type = str;
      default = config.campground.services.vault-agent.settings.vault.address;
      description = "The address of your Vault";
    };

    users = mkOption {
      type = attrsOf (attrsOf (listOf str));
      default = {};
      description = "The list of users and their secrets.";
    };
  };

  config = mkIf cfg.enable {
    campground.services.vault-agent.services = lib.mapAttrs' (user: secrets: {
      name = "user-secrets-${user}";
      value = {
        enable = true;
        settings = {
          vault.address = cfg.vault-address;
          auto_auth.method = [{
            type = "approle";
            config = {
              role_id_file_path = cfg.role-id;
              secret_id_file_path = cfg.secret-id;
              remove_secret_id_file_after_reading = false;
            };
          }];
        };
        secrets.file.files = lib.listToAttrs (map (secret: {
          name = "${user}-${secret}";
          value = {
            text = ''{{ with secret "secret/campground/users/${user}" }}{{ .Data.${secret} }}{{ end }}'';
            permissions = "0400";
            change-action = "restart";
          };
        }) secrets.files);
      };
    }) cfg.users;

      # Create systemd services for each user to handle secret copying
    systemd.services = lib.mapAttrs' (user: secrets: {
      name = "user-secrets-${user}";
      value = {
        description = "Copy Secret Service for ${user}";
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
        ExecStart = "${pkgs.bash}/bin/bash -c 'rm -rf /var/lib/vault/users/${user} && mkdir -p /var/lib/vault/users/${user} && chown ${user} /var/lib/vault/users/${user} && chmod 0700 /var/lib/vault/users/${user} && echo Move files && for secret in ${lib.concatStringsSep " " secrets.files}; do cp /tmp/detsys-vault/${user}-$secret /var/lib/vault/users/${user}/$secret && chown ${user} /var/lib/vault/users/${user}/$secret && chmod 0400 /var/lib/vault/users/${user}/$secret; done'";
          Type = "oneshot";
        };
      };
    }) cfg.users;
  };


}

