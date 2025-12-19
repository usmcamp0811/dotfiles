{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.photoprism;
  # If you setup Syncthing to sync with your phone and have the sync folder mapped to cfg.importPath then this will automatically import whenever you take a pic
in {
  options.fmf.services.photoprism = with types; {
    enable = mkBoolOpt false "Enable Photoprisim;";
    originalsPath = mkOpt str "" "Path to store original photos";
    importPath = mkOpt str "/webb/media/phone-pictures" "Path to import folder";
    port = mkOpt int 9080 "Port to expose Photoprism on";

    role-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.role-id
      "Absolute path to the Vault role-id";
    secret-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.secret-id
      "Absolute path to the Vault secret-id";
    vault-path =
      mkOpt str "secret/campground/photoprism"
      "The Vault path to the KV containing the KVs that are for each database";
    kvVersion = mkOption {
      type = enum ["v1" "v2"];
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
    fileSystems = {
      "/var/lib/private/photoprism/originals" =
        if cfg.originalsPath != ""
        then {
          device = cfg.originalsPath;
          options = ["bind"];
        }
        else null;
      "/var/lib/photoprism/import" =
        if cfg.importPath != ""
        then {
          device = cfg.importPath;
          options = ["bind"];
        }
        else null;
    };

    fmf.services.mysql = {
      enable = true;
      databases = [
        {
          name = "photoprism";
          user = "photoprism";
        }
      ];
    };
    services.nginx = {
      enable = true;
      virtualHosts = {
        "photoprism.lan" = {
          listen = [
            {
              addr = "0.0.0.0";
              port = cfg.port;
            }
          ]; # Specify the port here
          http2 = true;
          locations."/" = {
            proxyPass = "http://127.0.0.1:2342";
            proxyWebsockets = true;
          };
        };
      };
    };

    users.users.photoprism = {
      isNormalUser = false;
      isSystemUser = true;
      description = "Photoprism user";
      group = "photoprism";
      extraGroups = [
        "photoprism"
      ]; # Optional if you want the user to be in additional groups
      home = "/var/lib/photoprism";
    };

    users.groups.photoprism = {};

    systemd.services.photoprismAutoImport = {
      description = "Auto import when files are added to the folder";
      serviceConfig = {
        User = "root";
        Restart = "on-failure";
        WorkingDirectory = "/var/lib/photoprism";
      };
      wantedBy = ["multi-user.target"];
      after = ["photoprism.service"];
      script = ''
        export PHOTOPRISM_ADMIN_PASSWORD=$(cat "/var/lib/vault/photoprism.pass")
        ${pkgs.inotify-tools}/bin/inotifywait -m -e create "${cfg.importPath}" | while read path action file; do
          echo "File $file was added to ${cfg.importPath}. Running photoprism import."
          # wait a minute incase a lot of files go copied...
          sleep 60
          ${pkgs.sudo}/bin/sudo -u root /var/lib/photoprism/photoprism-manage import
        done
      '';
    };

    services.photoprism = {
      enable = true;
      port = 2342;
      originalsPath = "/var/lib/private/photoprism/originals";
      address = "127.0.0.1";
      passwordFile = "/var/lib/vault/photoprism.pass";
      importPath = "/var/lib/photoprism/import";
      settings = {
        PHOTOPRISM_ADMIN_USER = "admin";
        PHOTOPRISM_DEFAULT_LOCALE = "en";
        PHOTOPRISM_DATABASE_DRIVER = "mysql";
        PHOTOPRISM_DATABASE_NAME = "photoprism";
        PHOTOPRISM_DATABASE_SERVER = "/run/mysqld/mysqld.sock";
        PHOTOPRISM_DATABASE_USER = "photoprism";
        PHOTOPRISM_SITE_URL = "https://photos.aicampground.com";
        PHOTOPRISM_SITE_TITLE = "Campground Photos";
      };
    };

    fmf.services.vault-agent.services.photoprismPasswordFile = {
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
            "photoprism.pass" = {
              text = ''
                {{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.password }}{{ else }}{{ .Data.data.password }}{{ end }}{{ end }}
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
