{ lib, config, pkgs, ... }:
with lib;
with lib.fmf;
let cfg = config.fmf.services.onlyoffice;
in {
  options.fmf.services.onlyoffice = with types; {
    enable = mkBoolOpt false "Enable Nextcloud";
    domain =
      mkOpt str "office.aicampground.com" "Trusted Domain to serve Nextcloud On";
    # OnlyOffice configuration
    role-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.role-id
      "Absolute path to the Vault role-id";
    secret-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.secret-id
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
      default = config.fmf.services.vault-agent.settings.vault.address;
      description = "The address of your Vault";
    };
  };

  config = mkIf cfg.enable {

    # services.nextcloud.extraApps = {
    #   onlyoffice = pkgs.fetchNextcloudApp {
    #     url =
    #       "https://github.com/ONLYOFFICE/onlyoffice-nextcloud/releases/download/v9.2.2/onlyoffice.tar.gz";
    #     sha256 = "sha256-8Eyt3dyL2qqwIv3JP2C7Dw2FyQy0sDSZyxA0hMGR1O0="; # replace with the actual sha256
    #     license = pkgs.lib.licenses.gpl3.shortName;
    #   };
    # };

    services.onlyoffice = {
      enable = true;
      hostname = cfg.domain;
      port = 13449;

      postgresHost = "/run/postgresql";

      jwtSecretFile = "/tmp/detsys-vault/onlyoffice-jwt";
    };

    services.nginx = {
      enable = true;
      virtualHosts = {
        "office.aicampground.com" = {
          listen = [{
            addr = "0.0.0.0";
            port = 13450;
          }];
        };
      };
    };

    fmf.services.postgresql = {
      enable = true;
      enableTCPIP = true;
      backupEnable = true;
      authentication = [
        "local onlyoffice onlyoffice trust" 
      ];
      databases = [{
        name = "onlyoffice";
        user = "onlyoffice";
      }];
    };

    services.redis.servers."".enable = true;

    services.rabbitmq = { enable = true; };

    # OnlyOffice service configuration

    fmf.services.vault-agent.services.onlyoffice-docservice = {
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
              text = ''{{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.jwttoken }}{{ else }}{{ .Data.data.jwttoken }}{{ end }}{{ end }}'';
              permissions = "0600";
              change-action = "restart";
            };
          };
        };
      };
    };
  };
}
