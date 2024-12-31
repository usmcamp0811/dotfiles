{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.paperless;
  package = config.services.paperless.package;
  # Extract the default script
  hacked-web-script =
    let secretKeyFile = "${cfg.dataDir}/nixos-paperless-secret-key";
    in ''
      # Set the PAPERLESS_SOCIALACCOUNT_PROVIDERS variable
      PAPERLESS_SOCIALACCOUNT_PROVIDERS=$(cat /var/lib/vault/paperless.oidc)
      export PAPERLESS_SOCIALACCOUNT_PROVIDERS
      if [[ ! -f '${secretKeyFile}' ]]; then
        (
          umask 0377
          tr -dc A-Za-z0-9 < /dev/urandom | head -c64 | ${pkgs.moreutils}/bin/sponge '${secretKeyFile}'
        )
      fi
      PAPERLESS_SECRET_KEY="$(cat '${secretKeyFile}')"
      export PAPERLESS_SECRET_KEY
      if [[ ! $PAPERLESS_SECRET_KEY ]]; then
        echo "PAPERLESS_SECRET_KEY is empty, refusing to start."
        exit 1
      fi
      exec ${package.python.pkgs.gunicorn}/bin/gunicorn \
        -c ${package}/lib/paperless-ngx/gunicorn.conf.py paperless.asgi:application
    '';

in
{
  options.campground.services.paperless = with types; {
    enable = mkBoolOpt false "Enable Mattermost;";
    dataDir = mkOpt str "/var/lib/paperless" "Location to store data";
    mediaDir = mkOpt str "/var/lib/paperless/media" "Location to store media";
    port = mkOpt int 28981 "Port for https access";
    consumptionDir =
      mkOpt str "/var/lib/paperless/consume" "Place to import files from";
    address = mkOpt str "localhost" "Host address";
    gotenbergPort = mkOpt str "3000" "Gotenberg Port";
    tikaPort = mkOpt str "9998" "Tika Port";
    domainName = mkOpt str "https://docs.lan.aicampground.com" "domain to use";
    oidc-auth = mkBoolOpt true "Enable Authentik Login";
    role-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.role-id
        "Absolute path to the Vault role-id";
    secret-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.secret-id
        "Absolute path to the Vault secret-id";
    vault-path = mkOpt str "secret/campground/paperless"
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
    campground.services.postgresql = {
      enable = true;
      authentication = [
        "local paperless paperless trust"
        "host paperless paperless 127.0.0.1/32 trust"
      ];
      databases = [{
        name = "paperless";
        user = "paperless";
      }];
    };

    services.paperless = {
      enable = true;
      dataDir = cfg.dataDir;
      mediaDir = cfg.mediaDir;
      consumptionDir = cfg.consumptionDir;
      passwordFile = "/var/lib/vault/paperless.pass";
      address = "0.0.0.0";
      port = cfg.port;
      user = "paperless";
      package = pkgs.paperless-ngx;
      settings = {
        PAPERLESS_URL = cfg.domainName;

        # NOTE: Be sure to set a password for the paperless db user cause i had issues being able to connect
        # required setting up the db in one go and then deploy again with this.. my db game needs work
        # if you neglect the above there is a chance it will use SQLite as a fall back.. but might not now
        # that I set a dbhost. ¯\_(ツ)_/¯
        PAPERLESS_DBHOST = "/run/postgresql";
        # PAPERLESS_DBHOST = "127.0.0.1";

        PAPERLESS_OCR_LANGUAGE = "eng";
        PAPERLESS_TASK_WORKERS = 4;
        PAPERLESS_THREADS_PER_WORKER = 8;

        PAPERLESS_TIKA_ENABLED = true;
        PAPERLESS_TIKA_ENDPOINT = "http://127.0.0.1:${cfg.tikaPort}";
        PAPERLESS_TIKA_GOTENBERG_ENDPOINT =
          "http://127.0.0.1:${cfg.gotenbergPort}";

        PAPERLESS_EMAIL_TASK_CRON = "*/5 * * * *";
        PAPERLESS_APPS =
          mkIf cfg.oidc-auth "allauth.socialaccount.providers.openid_connect";
      };
    };

    systemd.services.paperlessPasswordFile = {
      description = "Create Paperless environment file";
      serviceConfig = {
        Type = "oneshot";
        User =
          "root"; # Use the root user to create the folder and set permissions
        ExecStartPre =
          "${pkgs.coreutils}/bin/chown root:root /var/lib/vault"; # Set folder ownership to root
      };
      script = ''
        ${pkgs.coreutils}/bin/cp /tmp/detsys-vault/paperless.pass /var/lib/vault/paperless.pass
        ${pkgs.coreutils}/bin/cp /tmp/detsys-vault/paperless.oidc /var/lib/vault/paperless.oidc
      '';
      postStart = ''
        ${pkgs.coreutils}/bin/chown paperless:paperless /var/lib/vault/paperless.pass
        ${pkgs.coreutils}/bin/chown paperless:paperless /var/lib/vault/paperless.oidc
      '';
      wantedBy = [ "multi-user.target" ];
      before = [ "paperless-web.service" ];
    };
    systemd.services.paperless-web.script =
      mkIf cfg.oidc-auth hacked-web-script;
    virtualisation.oci-containers.containers.gotenberg = {
      user = "gotenberg:gotenberg";
      image = "gotenberg/gotenberg:7.8.1";

      cmd = [
        "gotenberg"
        "--chromium-disable-javascript=true"
        "--chromium-allow-list=file:///tmp/.*"
      ];

      ports = [ "127.0.0.1:${cfg.gotenbergPort}:3000" ];
    };

    virtualisation.oci-containers.containers.tika = {
      image = "apache/tika:2.4.0";

      ports = [ "127.0.0.1:${cfg.tikaPort}:9998" ];
    };

    campground.services.vault-agent.services = {
      paperlessPasswordFile = {
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
              "paperless.oidc" = {
                text = ''
                  {{ with secret "${cfg.vault-path}" }}
                  {"openid_connect":{"OAUTH_PKCE_ENABLED":true,"APPS":[{"provider_id":"authentik","name":"Authentik","client_id":"{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.CLIENT_ID }}{{ else }}{{ .Data.data.CLIENT_ID }}{{ end }}","secret":"{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.CLIENT_SECRET }}{{ else }}{{ .Data.data.CLIENT_SECRET }}{{ end }}","settings":{"server_url":"https://auth.aicampground.com/application/o/paperless/.well-known/openid-configuration"}}]}}
                  {{ end }}
                '';
                permissions = "0600";
                change-action = "restart";
              };
              "paperless.pass" = {
                text = ''
                  {{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.password }}{{ else }}{{ .Data.data.password }}{{ end }}{{ end }}'';
                permissions = "0600";
                change-action = "restart";
              };
            };
          };
        };
      };
    };
  };
}
