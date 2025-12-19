{ lib, config, pkgs, ... }:
with lib;
with lib.fmf;
let cfg = config.fmf.services.remark42;
in {
  options.fmf.services.remark42 = with types; {
    enable = mkBoolOpt false "Enable an Searx;";
    port = mkOpt int 11845 "Port to Host the remark42 server on.";
    remark-url =
      mkOpt str "https://remark.aicampground.com" "URL for Remark server";
    site = mkOpt str "blog.aicampground.com" "Remark Site";
    emoji = mkOpt bool true "Enable Emoji support or not";
    role-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.role-id
      "Absolute path to the Vault role-id";
    secret-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.secret-id
      "Absolute path to the Vault secret-id";
    vault-path = mkOpt str "secret/campground/remark42"
      "The Vault path to the KV containing the Searx Secrets.";
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
    networking.firewall.allowedTCPPorts = [ cfg.port ];

    systemd.tmpfiles.rules =
      [ "d /var/lib/remark42/assets 700 remark42 remark42 -" ];
    users.users.remark42 = {
      isSystemUser = true;
      group = "remark42";
      home = "/var/lib/remark42";
      createHome = true;
    };

    users.groups.remark42 = { };

    systemd.services.remark42-blog-comments = {
      enable = true;
      description = "Comment engine for ${cfg.site}";
      environment = {
        REMARK_URL = cfg.remark-url;
        STORE_BOLT_PATH = "/var/lib/remark42/db";
        REMARK_PORT = "${toString cfg.port}";
        SITE = cfg.site;
        EMOJI = "${toString cfg.emoji}";
        NOTIFY_EMAIL_FROM = "blog-notify-no-reply@aicampground.com";
        AUTH_EMAIL_FROM = "blot-auth-no-reply@aicampground.com";
        CORS_ALLOWED_ORIGINS = "https://${cfg.site}:remark.aicampgroud.com";
      };
      serviceConfig = {
        ExecStart = "${pkgs.fmf.remark42}/bin/remark42 server";
        Restart = "always";
        RestartSec = 30;
        # StandardOutput = "journal";
        WorkingDirectory = "/var/lib/remark42/assets";
        User = "remark42";
        Group = "remark42";
      };
    };

    fmf.services.vault-agent.services.remark42-blog-comments = {
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
        environment.templates = {
          secret-service-env = {
            text = ''
              {{ with secret "${cfg.vault-path}" }}
              SECRET="{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.SECRET }}{{ else }}{{ .Data.data.SECRET }}{{ end }}"
              SMTP_HOST="{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.SMTP_HOST }}{{ else }}{{ .Data.data.SMTP_HOST }}{{ end }}"
              SMTP_PORT="{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.SMTP_PORT }}{{ else }}{{ .Data.data.SMTP_PORT }}{{ end }}"
              SMTP_TLS="{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.SMTP_TLS }}{{ else }}{{ .Data.data.SMTP_TLS }}{{ end }}"
              SMTP_USERNAME="{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.SMTP_USERNAME }}{{ else }}{{ .Data.data.SMTP_USERNAME }}{{ end }}"
              SMTP_PASSWORD="{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.SMTP_PASSWORD }}{{ else }}{{ .Data.data.SMTP_PASSWORD }}{{ end }}"
              AUTH_GITHUB_CID="{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.AUTH_GITHUB_CID }}{{ else }}{{ .Data.data.AUTH_GITHUB_CID }}{{ end }}"
              AUTH_GITHUB_CSEC="{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.AUTH_GITHUB_CSEC }}{{ else }}{{ .Data.data.AUTH_GITHUB_CSEC  }}{{ end }}"
              AUTH_GOOGLE_CID="{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.AUTH_GOOGLE_CID }}{{ else }}{{ .Data.data.AUTH_GOOGLE_CID }}{{ end }}"
              AUTH_GOOGLE_CSEC="{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.AUTH_GOOGLE_CSEC }}{{ else }}{{ .Data.data.AUTH_GOOGLE_CSEC  }}{{ end }}"
              {{ end }}
            '';
          };
        };
      };
    };
  };
}
