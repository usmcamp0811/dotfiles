{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.services.lemmy;
in {
  options.campground.services.lemmy = with types; {
    enable = mkEnableOption "Lemmy";
    user = mkOpt types.str "lemmy" "The user under which lemmy runs.";
    group = mkOpt types.str "lemmy" "The group under which lemmy runs.";
    site_name = mkOpt types.str "Campground" "Site Name";
    port = mkOpt types.int 19533 "Port for the Lemmy UI.";
    ui.port = mkOpt types.int 19536 "Port for the Lemmy UI.";
    server.port = mkOpt types.int 18537 "Port for the Lemmy server.";
    hostname = mkOpt types.str "lemmy.aicampground.com" "Hostname for Lemmy.";
    captcha = {
      enabled = mkOpt types.bool false "Enable captcha for Lemmy.";
      difficulty = mkOpt types.str "easy" "Captcha difficulty level.";
    };
    pict-rs-port = mkOpt types.int 18824 "pict-rs port";

    role-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.role-id
        "Absolute path to the Vault role-id";
    secret-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.secret-id
        "Absolute path to the Vault secret-id";
    vault-path = mkOpt str "secret/campground/lemmy"
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
    users = {
      users = {
        "${cfg.user}" = {
          group = "${cfg.group}";
          isSystemUser = true;
        };
      };
      groups = { "${cfg.group}" = { }; };
    };

    campground.services.postgresql = {
      enable = true;
      databases = [{
        name = "lemmy";
        user = "${cfg.user}";
      }];
      authentication = [ "local   lemmy    lemmy   trust" ];
    };
    services.nginx.virtualHosts."${cfg.hostname}".listen = [{
      addr = "0.0.0.0";
      port = cfg.port;
    }];

    services.lemmy = {
      enable = true;
      ui.port = cfg.ui.port;
      nginx.enable = true;
      database = {
        createLocally = true;
        uri = "postgres:///lemmy?host=/run/postgresql&user=lemmy";
      };
      # pictrsApiKeyFile = "/run/lemmy/pictrs_api_key";
      settings = {
        port = cfg.server.port;
        hostname = cfg.hostname;
        bind = "0.0.0.0";
        site_name = cfg.site_name;
        captcha = {
          enabled = cfg.captcha.enabled;
          difficulty = cfg.captcha.difficulty;
        };
        email = { tls_type = "starttls"; };
      };
    };

    systemd.services.lemmy = {
      environment = {
        LEMMY_CONFIG_LOCATION = mkForce "/run/lemmy/config.hjson";
      };
      preStart = ''
        ${pkgs.coreutils}/bin/mkdir -p /run/lemmy/
        ${pkgs.jq}/bin/jq -s 'reduce .[] as $item ({}; . * $item)' \
          /tmp/detsys-vault/lemmySecretConfig.json \
          <<< '${builtins.toJSON config.services.lemmy.settings}' \
          > /run/lemmy/config.hjson
        cp /tmp/detsys-vault/pictrs_api_key /run/lemmy/
        ${pkgs.coreutils}/bin/chmod 600 /run/lemmy/config.hjson
        ${pkgs.coreutils}/bin/chown ${cfg.user}:${cfg.group} /run/lemmy/config.hjson 
        ${pkgs.coreutils}/bin/chown ${cfg.user}:${cfg.group} /run/lemmy/pictrs_api_key
      '';
      path = with pkgs; [ ps busybox coreutils ];
      serviceConfig = {
        ExecStart = mkForce
          "${pkgs.su}/bin/su -s /bin/sh -c '${config.services.lemmy.server.package}/bin/lemmy_server' - lemmy";
        User = "root";
      };

    };
    services.pict-rs.package = pkgs.pict-rs;
    services.pict-rs.port = cfg.pict-rs-port;
    campground.services.vault-agent.services.lemmy = {
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
            "pictrs_api_key" = {
              text = ''
                {{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.LEMMY_PICTRS_API_KEY }}{{ else }}{{ .Data.data.LEMMY_PICTRS_API_KEY }}{{ end }}{{ end }}
              '';
              permissions = "0600";
              change-action = "restart";
            };
            "lemmySecretConfig.json" = {
              text = ''
                {{ with secret "${cfg.vault-path}" }}
                {
                  "email": {
                    "smtp_server": "{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.LEMMY_SMTP_SERVER }}{{ else }}{{ .Data.data.LEMMY_SMTP_SERVER }}{{ end }}",
                    "smtp_login": "{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.LEMMY_SMTP_LOGIN }}{{ else }}{{ .Data.data.LEMMY_SMTP_LOGIN }}{{ end }}",
                    "smtp_password": "{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.LEMMY_SMTP_PASSWORD }}{{ else }}{{ .Data.data.LEMMY_SMTP_PASSWORD }}{{ end }}",
                    "smtp_from_address": "noreply@lemmy.aicampground.com",
                    "tls_type": "starttls"
                  },
                  "setup": {
                    "admin_username": "admin",
                    "admin_password": "{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.LEMMY_ADMIN_PASSWORD }}{{ else }}{{ .Data.data.LEMMY_ADMIN_PASSWORD }}{{ end }}",
                    "site_name": "Campground"
                  },
                 "pictrs": {
                   "api_key": "{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.LEMMY_PICTRS_API_KEY }}{{ else }}{{ .Data.data.LEMMY_PICTRS_API_KEY }}{{ end }}"
                 },
                  "hostname": "lemmy.campground.com",
                  "bind": "0.0.0.0"
                }
                {{ end }}
              '';
              permissions = "0600";
              change-action = "restart";
            };
          };
        };
        # environment.templates = {
        #   lemmy = {
        #     text = ''
        #       {{ with secret "${cfg.vault-path}" }}
        #       LEMMY_SMTP_PASSWORD={{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.LEMMY_SMTP_PASSWORD }}{{ else }}{{ .Data.data.LEMMY_SMTP_PASSWORD }}{{ end }}
        #       LEMMY_SMTP_SERVER={{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.LEMMY_SMTP_SERVER }}{{ else }}{{ .Data.data.LEMMY_SMTP_SERVER }}{{ end }}
        #       LEMMY_SMTP_LOGIN={{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.LEMMY_SMTP_LOGIN }}{{ else }}{{ .Data.data.LEMMY_SMTP_LOGIN }}{{ end }}
        #       LEMMY_SMTP_FROM_ADDRESS={{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.LEMMY_SMTP_FROM_ADDRESS }}{{ else }}{{ .Data.data.LEMMY_SMTP_FROM_ADDRESS }}{{ end }}
        #       LEMMY_PICTRS_API_KEY={{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.LEMMY_PICTRS_API_KEY }}{{ else }}{{ .Data.data.LEMMY_PICTRS_API_KEY }}{{ end }}
        #       LEMMY_ADMIN_PASSWORD={{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.LEMMY_ADMIN_PASSWORD }}{{ else }}{{ .Data.data.LEMMY_ADMIN_PASSWORD }}{{ end }}
        #       LEMMY_ADMIN_EMAIL={{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.LEMMY_ADMIN_EMAIL }}{{ else }}{{ .Data.data.LEMMY_ADMIN_EMAIL }}{{ end }}
        #       {{ end }}
        #     '';
        #   };
        # };
      };
    };
  };
}
