{ lib
, config
, pkgs
, ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.system.passwds;
in
{
  options.campground.system.passwds = with types; {
    enable = mkBoolOpt false "Set Local User Passwords with Vault";
    role-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.role-id
        "Absolute path to the Vault role-id";
    secret-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.secret-id
        "Absolute path to the Vault secret-id";
    vault-address = mkOption {
      type = str;
      default = config.campground.services.vault-agent.settings.vault.address;
      description = "The address of your Vault";
    };
    vault-path =
      mkOpt str "secret/campground/local-users-passwords"
        "The Vault path to the KV containing the Wifi Secrets.";
    kvVersion = mkOption {
      type = enum [ "v1" "v2" ];
      default = "v2";
      description = "KV store version";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.passwds = {
      description = "Set/update Local User & Root User Passwords";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.bash}/bin/bash /tmp/detsys-vault/set-passwds";
        Environment = "PATH=${pkgs.shadow}/bin:${pkgs.coreutils}/bin:${config.system.path}/bin";
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };

    campground.services.vault-agent.services.passwds = {
      settings = {
        vault.address = cfg.vault-address;
        auto_auth = {
          method = [
            {
              type = "approle";
              config = {
                role_id_file_path = cfg.role-id;
                secret_id_file_path = cfg.secret-id;
                remove_secret_id_file_after_reading = false;
              };
            }
          ];
        };
      };
      secrets = {
        file = {
          files = {
            "set-passwds" = {
              text = ''
                #!/bin/sh
                USERNAME=${config.campground.user.name}
                PASSWORD="{{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.${config.campground.user.name} }}{{ else }}{{ .Data.data.${config.campground.user.name} }}{{ end }}{{ end }}"
                ROOT_PASSWORD="{{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.root }}{{ else }}{{ .Data.data.root }}{{ end }}{{ end }}"

                printf "Setting $USERNAME Password from Vault"
                echo -e "$PASSWORD\n$PASSWORD" | passwd $USERNAME

                printf "Setting root Password from Vault"
                echo -e "$ROOT_PASSWORD\n$ROOT_PASSWORD" | passwd root
              '';
              permissions = "0400";
              change-action = "restart";
            };
          };
        };
      };
    };
  };
}
