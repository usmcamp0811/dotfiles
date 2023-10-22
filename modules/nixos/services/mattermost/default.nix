{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.mattermost;
in
{
  options.campground.services.mattermost = with types; {
    enable = mkBoolOpt false "Enable Mattermost;";
  };

  config = mkIf cfg.enable {
    services.mattermost = {
      enable = true;

      siteUrl = "https://mattermost.aicampground.com";
      listenAddress = "127.0.0.1:8065";

      # TODO reevaluate option on fresh install
      # Database was created before this option existed. Also using this
      # requires to put add the password to the nix store.
      localDatabaseCreate = false;

      extraConfig = {
        ServiceSettings = {
          EnableEmailInvitations = true;
          EnableOAuthServiceProvider = true;
          TrustedProxyIPHeader = [ "X-Forwarded-For" "X-Real-IP" ];
          AllowCorsFrom = "*";
        };

        FileSettings.Directory = "/var/lib/mattermost/files";
      };
    };


    lollypops.secrets.files."mattermost/envfile" = { };

    systemd.services.mattermost = {

      serviceConfig = {

        EnvironmentFile = "/tmp/detsys-";

        Environment = [

          # TODO Check syntax for header

          # Secret envfile contains:
          # MM_EMAILSETTINGS_CONNECTIONSECURITY=
          # MM_EMAILSETTINGS_ENABLEPREVIEWMODEBANNER=
          # MM_EMAILSETTINGS_ENABLESMTPAUTH=
          # MM_EMAILSETTINGS_FEEDBACKEMAIL=
          # MM_EMAILSETTINGS_PUSHNOTIFICATIONCONTENTS=
          # MM_EMAILSETTINGS_REPLYTOADDRESS=
          # MM_EMAILSETTINGS_SENDEMAILNOTIFICATIONS=
          # MM_EMAILSETTINGS_SMTPPASSWORD=
          # MM_EMAILSETTINGS_SMTPPORT=
          # MM_EMAILSETTINGS_SMTPSERVER=
          # MM_EMAILSETTINGS_SMTPUSERNAME=
          # MM_FILESETTINGS_PUBLICLINKSALT=
          # MM_SQLSETTINGS_ATRESTENCRYPTKEY=
          # MM_SQLSETTINGS_DATASOURCE=
          # MM_EXTRA_SQLSETTINGS_DB_PASSWORD=
        ];
      };
    };

    campground.services.vault-agent.services.mattermost = {
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
            "mattermost.env" = {
              text = ''{{ with secret "${cfg.vault-path}" }}
    {{ if eq "${cfg.kvVersion}" "v1" }}
    DOMAIN={{ .Data.DOMAIN }}
    TZ={{ .Data.TZ }}
    RESTART_POLICY={{ .Data.RESTART_POLICY }}
    POSTGRES_IMAGE_TAG={{ .Data.POSTGRES_IMAGE_TAG }}
    POSTGRES_DATA_PATH={{ .Data.POSTGRES_DATA_PATH }}
    POSTGRES_USER={{ .Data.POSTGRES_USER }}
    POSTGRES_PASSWORD={{ .Data.POSTGRES_PASSWORD }}
    POSTGRES_DB={{ .Data.POSTGRES_DB }}
    NGINX_IMAGE_TAG={{ .Data.NGINX_IMAGE_TAG }}
    NGINX_CONFIG_PATH={{ .Data.NGINX_CONFIG_PATH }}
    NGINX_DHPARAMS_FILE={{ .Data.NGINX_DHPARAMS_FILE }}
    CERT_PATH={{ .Data.CERT_PATH }}
    KEY_PATH={{ .Data.KEY_PATH }}
    HTTPS_PORT={{ .Data.HTTPS_PORT }}
    HTTP_PORT={{ .Data.HTTP_PORT }}
    CALLS_PORT={{ .Data.CALLS_PORT }}
    MATTERMOST_CONFIG_PATH={{ .Data.MATTERMOST_CONFIG_PATH }}
    MATTERMOST_DATA_PATH={{ .Data.MATTERMOST_DATA_PATH }}
    MATTERMOST_LOGS_PATH={{ .Data.MATTERMOST_LOGS_PATH }}
    MATTERMOST_PLUGINS_PATH={{ .Data.MATTERMOST_PLUGINS_PATH }}
    MATTERMOST_CLIENT_PLUGINS_PATH={{ .Data.MATTERMOST_CLIENT_PLUGINS_PATH }}
    MATTERMOST_BLEVE_INDEXES_PATH={{ .Data.MATTERMOST_BLEVE_INDEXES_PATH }}
    MM_BLEVESETTINGS_INDEXDIR={{ .Data.MM_BLEVESETTINGS_INDEXDIR }}
    MATTERMOST_IMAGE={{ .Data.MATTERMOST_IMAGE }}
    MATTERMOST_IMAGE_TAG={{ .Data.MATTERMOST_IMAGE_TAG }}
    MATTERMOST_CONTAINER_READONLY={{ .Data.MATTERMOST_CONTAINER_READONLY }}
    APP_PORT={{ .Data.APP_PORT }}
    MM_SQLSETTINGS_DRIVERNAME={{ .Data.MM_SQLSETTINGS_DRIVERNAME }}
    MM_SQLSETTINGS_DATASOURCE=postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}?sslmode=disable&connect_timeout=10
    MM_SERVICESETTINGS_SITEURL=https://${DOMAIN}
    {{ else }}
    DOMAIN={{ .Data.data.DOMAIN }}
    TZ={{ .Data.data.TZ }}
    RESTART_POLICY={{ .Data.data.RESTART_POLICY }}
    POSTGRES_IMAGE_TAG={{ .Data.data.POSTGRES_IMAGE_TAG }}
    POSTGRES_DATA_PATH={{ .Data.data.POSTGRES_DATA_PATH }}
    POSTGRES_USER={{ .Data.data.POSTGRES_USER }}
    POSTGRES_PASSWORD={{ .Data.data.POSTGRES_PASSWORD }}
    POSTGRES_DB={{ .Data.data.POSTGRES_DB }}
    NGINX_IMAGE_TAG={{ .Data.data.NGINX_IMAGE_TAG }}
    NGINX_CONFIG_PATH={{ .Data.data.NGINX_CONFIG_PATH }}
    NGINX_DHPARAMS_FILE={{ .Data.data.NGINX_DHPARAMS_FILE }}
    CERT_PATH={{ .Data.data.CERT_PATH }}
    KEY_PATH={{ .Data.data.KEY_PATH }}
    HTTPS_PORT={{ .Data.data.HTTPS_PORT }}
    HTTP_PORT={{ .Data.data.HTTP_PORT }}
    CALLS_PORT={{ .Data.data.CALLS_PORT }}
    MATTERMOST_CONFIG_PATH={{ .Data.data.MATTERMOST_CONFIG_PATH }}
    MATTERMOST_DATA_PATH={{ .Data.data.MATTERMOST_DATA_PATH }}
    MATTERMOST_LOGS_PATH={{ .Data.data.MATTERMOST_LOGS_PATH }}
    MATTERMOST_PLUGINS_PATH={{ .Data.data.MATTERMOST_PLUGINS_PATH }}
    MATTERMOST_CLIENT_PLUGINS_PATH={{ .Data.data.MATTERMOST_CLIENT_PLUGINS_PATH }}
    MATTERMOST_BLEVE_INDEXES_PATH={{ .Data.data.MATTERMOST_BLEVE_INDEXES_PATH }}
    MM_BLEVESETTINGS_INDEXDIR={{ .Data.data.MM_BLEVESETTINGS_INDEXDIR }}
    MATTERMOST_IMAGE={{ .Data.data.MATTERMOST_IMAGE }}
    MATTERMOST_IMAGE_TAG={{ .Data.data.MATTERMOST_IMAGE_TAG }}
    MATTERMOST_CONTAINER_READONLY={{ .Data.data.MATTERMOST_CONTAINER_READONLY }}
    APP_PORT={{ .Data.data.APP_PORT }}
    MM_SQLSETTINGS_DRIVERNAME={{ .Data.data.MM_SQLSETTINGS_DRIVERNAME }}
    MM_SQLSETTINGS_DATASOURCE=postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}?sslmode=disable&connect_timeout=10
    MM_SERVICESETTINGS_SITEURL=https://${DOMAIN}
    {{ end }}
    {{ end }}'';
              permissions = "0600";
              change-action = "restart";
            };
          };
        };
      };
    };

  };
}
