{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.services.firefly;
in {
  options.campground.services.firefly = with types; {
    enable = mkBoolOpt false "Enable Firefly III.";
    port = mkOpt int 16244 "Port for firefly";
    firefly-user = mkOpt str "firefly" "user for Firefly III.";
    firefly-group = mkOpt str "firefly" "user for Firefly III.";
    dataDir = mkOpt str "/var/lib/${cfg.firefly-user}"
      "Data directory for Firefly III.";
    settings = mkOption {
      type = attrs;
      default = {
        SITE_OWNER = "matt@aicampground.com";
        APP_URL = "https://${cfg.virtualHost}";
        APP_DEBUG = true;
        DB_SOCKET = "/run/postgresql";
        DB_NAME = "firefly";
        DB_CONNECTION = "pgsql";
        APP_KEY_FILE = "/var/lib/firefly/key.file";
        APP_ENV = "production";
        TRUSTED_PROXIES = "10.0.0.0/8,192.168.0.0/16,172.16.0.0/12";
      };
      description = "Settings for Firefly III.";
    };
    virtualHost =
      mkOpt str "firefly.lan.aicampground.com" "Virtual host for Firefly III.";
    package = mkOpt types.package pkgs.firefly-iii "Package for Firefly III.";
    poolConfig = mkOpt attrs
      {
        "listen.owner" = mkDefault "nginx";
        "listen.group" = mkDefault "nginx";
        pm = "dynamic";
        "pm.max_children" = 32;
        "pm.max_requests" = 500;
        "pm.max_spare_servers" = 4;
        "pm.min_spare_servers" = 2;
        "pm.start_servers" = 2;
      } "Pool configuration for Firefly III.";

    role-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.role-id
        "Absolute path to the Vault role-id";
    secret-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.secret-id
        "Absolute path to the Vault secret-id";
    vault-path = mkOpt str "secret/campground/firefly"
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
    services.phpfpm.pools.firefly-iii = {
      user = mkDefault cfg.firefly-user;
      group = mkDefault cfg.firefly-group;
    };
    services.nginx = {
      enable = true;
      virtualHosts.${cfg.virtualHost} = {
        listen = [{
          addr = "0.0.0.0";
          port = cfg.port;
        }];
      };
    };

    systemd.services.get-firefly-key = {
      description = "Gets the Firefly Key File";
      wantedBy = [ "multi-user.target" ];
      before = [ "firefly-iii-setup.service" ];
      script = ''
        mkdir -p /var/lib/${cfg.firefly-user}
        cat /tmp/detsys-vault/key.file > /var/lib/${cfg.firefly-user}/key.file
        chown -R ${cfg.firefly-user}:${cfg.firefly-group} /var/lib/${cfg.firefly-user}/key.file
      '';
      serviceConfig = { Type = "oneshot"; };
    };
    users = {
      users = {
        ${cfg.firefly-user} = {
          description = "Firefly-iii service user";
          group = cfg.firefly-group;
          isSystemUser = true;
          home = cfg.dataDir;
        };
      };
      groups = { ${cfg.firefly-group} = { }; };
    };
    campground.services.postgresql = {
      enable = true;
      authentication = [ "local firefly firefly trust" ];
      databases = [{
        name = "firefly";
        user = "firefly";
      }];
    };
    services.firefly-iii = {
      enable = true;
      user = cfg.firefly-user;
      group = cfg.firefly-group;
      dataDir = cfg.dataDir;
      settings = cfg.settings;
      virtualHost = cfg.virtualHost;
      package = cfg.package;
      enableNginx = true;
      poolConfig = cfg.poolConfig;
    };
    campground.services = {
      vault-agent = {
        services = {
          "get-firefly-key" = {
            settings = {
              # replace with the address of your vault
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
                  "key.file" = {
                    text = ''
                      {{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.key }}{{ else }}{{ .Data.data.key }}{{ end }}{{ end }}'';
                    permissions = "0600";
                    change-action = "restart";
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
