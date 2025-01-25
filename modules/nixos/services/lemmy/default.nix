{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.services.lemmy;
in {
  options.campground.services.lemmy = {
    enable = mkEnableOption "Lemmy";
    ui.port = mkOpt types.int 19536 "Port for the Lemmy UI.";
    server.port = mkOpt types.int 18537 "Port for the Lemmy server.";
    smtpPasswordFile = mkOpt types.path "/var/lib/lemmy/smtp-password"
      "Path to the SMTP password file.";
    adminPasswordFile = mkOpt types.path "/var/lib/lemmy/admin-password"
      "Path to the admin password file.";

    hostname =
      mkOpt types.str "lemmy.lan.aicampground.com" "Hostname for Lemmy.";
    captcha = {
      enabled = mkOpt types.bool false "Enable captcha for Lemmy.";
      difficulty = mkOpt types.str "easy" "Captcha difficulty level.";
    };

    pictrsApiKeyFile = mkOpt types.path "/var/lib/lemmy/pictrs-api-key"
      "Path to the Pictrs API key file.";
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

    campground.services.postgresql = mkIf cfg.database.createLocally {
      enable = true;
      databases = [{
        name = "lemmy";
        user = "${cfg.user}";
      }];
      authentication = [ "local   lemmy    lemmy   trust" ];
    };

    services.lemmy = {
      enable = true;
      ui.package = cfg.ui.package;
      server.package = cfg.server.package;
      ui.port = cfg.ui.port;
      database = {
        createLocally = true;
        uri = "postgres:///lemmy?host=/run/postgresql&user=lemmy";
      };
      settings = {
        port = cfg.server.port;
        hostname = cfg.hostname;
        captcha = {
          enabled = cfg.captcha.enabled;
          difficulty = cfg.captcha.difficulty;
        };
        email = { tls_type = "starttls"; };
      };
      smtpPasswordFile = cfg.smtpPasswordFile;
      adminPasswordFile = cfg.adminPasswordFile;
      pictrsApiKeyFile = cfg.pictrsApiKeyFile;
    };

    systemd.services.lemmySecrets = {
      description = "Manage Lemmy Secrets";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
      script = ''
        mkdir -p /var/lib/lemmy
        echo "smtp_password" > ${cfg.smtpPasswordFile}
        echo "admin_password" > ${cfg.adminPasswordFile}
        echo "pictrs_api_key" > ${cfg.pictrsApiKeyFile}
        chown ${cfg.user}:${cfg.group} /var/lib/lemmy/*
      '';
      wantedBy = [ "multi-user.target" ];
      before = [ "lemmy.service" ];
    };

    campground.services.vault-agent.services.lemmySecrets = {
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
            "mealie-creds" = {
              text = ''
                # SMTP Configuration
                LEMMY_SMTP_PASSWORD={{ with secret "{{ .vault-path }}" }}{{ if eq "{{ .kvVersion }}" "v1" }}{{ .Data.LEMMY_SMTP_PASSWORD }}{{ else }}{{ .Data.data.LEMMY_SMTP_PASSWORD }}{{ end }}{{ end }}
                LEMMY_SMTP_SERVER={{ with secret "{{ .vault-path }}" }}{{ if eq "{{ .kvVersion }}" "v1" }}{{ .Data.LEMMY_SMTP_SERVER }}{{ else }}{{ .Data.data.LEMMY_SMTP_SERVER }}{{ end }}{{ end }}
                LEMMY_SMTP_LOGIN={{ with secret "{{ .vault-path }}" }}{{ if eq "{{ .kvVersion }}" "v1" }}{{ .Data.LEMMY_SMTP_LOGIN }}{{ else }}{{ .Data.data.LEMMY_SMTP_LOGIN }}{{ end }}{{ end }}
                LEMMY_SMTP_FROM_ADDRESS={{ with secret "{{ .vault-path }}" }}{{ if eq "{{ .kvVersion }}" "v1" }}{{ .Data.LEMMY_SMTP_FROM_ADDRESS }}{{ else }}{{ .Data.data.LEMMY_SMTP_FROM_ADDRESS }}{{ end }}{{ end }}

                # Pictrs Configuration
                LEMMY_PICTRS_API_KEY={{ with secret "{{ .vault-path }}" }}{{ if eq "{{ .kvVersion }}" "v1" }}{{ .Data.LEMMY_PICTRS_API_KEY }}{{ else }}{{ .Data.data.LEMMY_PICTRS_API_KEY }}{{ end }}{{ end }}

                # Admin Setup Configuration
                LEMMY_ADMIN_PASSWORD={{ with secret "{{ .vault-path }}" }}{{ if eq "{{ .kvVersion }}" "v1" }}{{ .Data.LEMMY_ADMIN_PASSWORD }}{{ else }}{{ .Data.data.LEMMY_ADMIN_PASSWORD }}{{ end }}{{ end }}
                LEMMY_ADMIN_EMAIL={{ with secret "{{ .vault-path }}" }}{{ if eq "{{ .kvVersion }}" "v1" }}{{ .Data.LEMMY_ADMIN_EMAIL }}{{ else }}{{ .Data.data.LEMMY_ADMIN_EMAIL }}{{ end }}{{ end }}

                # General Configuration
                LEMMY_HOSTNAME={{ with secret "{{ .vault-path }}" }}{{ if eq "{{ .kvVersion }}" "v1" }}{{ .Data.LEMMY_HOSTNAME }}{{ else }}{{ .Data.data.LEMMY_HOSTNAME }}{{ end }}{{ end }}
                EOF
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
