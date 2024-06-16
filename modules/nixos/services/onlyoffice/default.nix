{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.services.onlyoffice;
in {
  options.campground.services.onlyoffice = with types; {
    enable = mkBoolOpt false "Enable Nextcloud";
    domain =
      mkOpt str "cloud.aicampground.com" "Trusted Domain to serve Nextcloud On";
    # OnlyOffice configuration
    role-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.role-id
      "Absolute path to the Vault role-id";
    secret-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.secret-id
      "Absolute path to the Vault secret-id";
    vault-path = mkOpt str "secret/campground/onlyoffice"
      "The Vault path to the KV containing the KVs that are for each database";
    kvVersion = mkOption {
      type = enum [ "v1" "v2" ];
      default = "v2";
      description = "KV store version";
    };
    vault-address = mkOption {
      type = str;
      default = config.campground.services.vault-agent.settings.vault.address;
      description = "The address of your Vault";
    };
  };

  config = mkIf cfg.enable {

    services.nextcloud.extraApps = {
      onlyoffice = pkgs.fetchNextcloudApp {
        url =
          "https://github.com/ONLYOFFICE/onlyoffice-nextcloud/releases/download/v9.2.2/onlyoffice.tar.gz";
        sha256 = "sha256-8Eyt3dyL2qqwIv3JP2C7Dw2FyQy0sDSZyxA0hMGR1O0="; # replace with the actual sha256
        license = pkgs.lib.licenses.gpl3.shortName;
      };
    };

    services.onlyoffice = {
      enable = true;
      hostname = "office.${cfg.domain}";
      port = 13444;

      postgresHost = "/run/postgresql";

      jwtSecretFile = "/tmp/detsys-vault/onlyoffice-jwt";
    };

    services.nginx.virtualHosts."office.${cfg.domain}" = {
      listen = [{
        addr = "0.0.0.0";
        port = 13249;
      }];
    };

    campground.services.postgresql = {
      enable = true;
      authentication = [ "local onlyoffice onlyoffice trust" ];
      databases = [{
        name = "onlyoffice";
        user = "onlyoffice";
      }];
    };

    services.redis = { enable = true; };

    services.rabbitmq = { enable = true; };

    # OnlyOffice service configuration

    campground.services.vault-agent.services.onlyoffice-docservice = {
      settings = {
        vault.address = cfg.vault-address;
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
          files = {
            "onlyoffice-jwt" = {
              text = ''
                {{ with secret "${cfg.vault-path}" }}
                {{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.jwttoken }}{{ else }}{{ .Data.data.jwttoken }}{{ end }}
                {{ end }}
              '';
              permissions = "0600";
              change-action = "restart";
            };
          };
        };
      };
    };
  };
}
