{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.services.lemmy;
in {
  options.campground.services.lemmy = with types; {
    enable = mkEnableOption "Lemmy";
    user = mkOpt types.str "lemmy" "The user under which lemmy runs.";
    group = mkOpt types.str "lemmy" "The group under which lemmy runs.";
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

    services.lemmy = {
      enable = true;
      ui.port = cfg.ui.port;
      database = {
        createLocally = true;
        uri = "postgres:///lemmy?host=/run/postgresql&user=lemmy";
      };
      pictrsApiKeyFile = "/tmp/detsys-vault/pictrsApiKeyFile";

      settings = {
        port = cfg.server.port;
        hostname = cfg.hostname;
        captcha = {
          enabled = cfg.captcha.enabled;
          difficulty = cfg.captcha.difficulty;
        };
        email = { tls_type = "starttls"; };
      };
    };

    systemd.services.lemmySecrets = {
      description = "Manage Lemmy Secrets";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
      script = ''
        mkdir -p /var/lib/lemmy
        cp /tmp/detsys-vault/stmpPasswordFile  > /var/lib/lemmy/smtpPasswordFile
        cp /tmp/detsys-vault/adminPasswordFile  > /var/lib/lemmy/adminPasswordFile
        cp /tmp/detsys-vault/pictrsApiKeyFile  > /var/lib/lemmy/pictrsApiKeyFile
        chown ${cfg.user}:${cfg.group} /var/lib/lemmy/*
      '';
      wantedBy = [ "multi-user.target" ];
      before = [ "lemmy.service" ];
    };
    services.pict-rs.package = pkgs.pict-rs;
    services.pict-rs.port = cfg.pict-rs-port;
    campground.services.vault-agent.services.lemmySecrets = {
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
            "smtpPasswordFile" = {
              text = ''
                {{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.LEMMY_SMTP_PASSWORD }}{{ else }}{{ .Data.data.LEMMY_SMTP_PASSWORD }}{{ end }}
              '';
              permissions = "0600";
              change-action = "restart";
            };
            "adminPasswordFile" = {
              text = ''
                {{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.LEMMY_ADMIN_PASSWORD }}{{ else }}{{ .Data.data.LEMMY_ADMIN_PASSWORD }}{{ end }}
              '';
              permissions = "0600";
              change-action = "restart";
            };
            "pictrsApiKeyFile" = {
              text = ''
                {{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.LEMMY_PICTRS_API_KEY }}{{ else }}{{ .Data.data.LEMMY_PICTRS_API_KEY }}{{ end }}
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
