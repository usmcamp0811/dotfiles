{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.gitea;

  # Store secrets in a dedicated directory
  secretsDir = "${cfg.stateDir}/secrets";

  secretPaths = {
    dbPassword = "${secretsDir}/db-password";
    secretKey = "${secretsDir}/secret-key";
    internalToken = "${secretsDir}/internal-token";
    lfsJwtSecret = "${secretsDir}/lfs-jwt-secret";
    oauth2JwtSecret = "${secretsDir}/oauth2-jwt-secret";
    smtpPassword = "${secretsDir}/smtp-password";
  };
in {
  options.fmf.services.gitea = with types; {
    enable = mkBoolOpt false "Enable Gitea";

    # Basic configuration
    domain = mkOpt str "git.lan.aicampground.com" "Gitea domain";
    port = mkOpt int 3000 "HTTP port to serve Gitea on";
    httpPort = mkOpt int 8445 "External HTTP port for nginx proxy";
    sshPort = mkOpt int 2222 "SSH port for Git operations";

    # Application configuration
    appName = mkOpt str "Gitea: Git with a cup of tea" "Application name";
    repositoryRoot = mkOpt str "/var/lib/gitea/repositories" "Path to Git repositories";
    stateDir = mkOpt str "/var/lib/gitea" "Gitea state directory";

    # Database configuration
    databaseType = mkOpt str "postgres" "Database type (postgres, mysql, sqlite3)";
    databaseHost = mkOpt str "/run/postgresql" "Database host (socket path for local PostgreSQL)";
    databaseName = mkOpt str "gitea" "Database name";
    databaseUser = mkOpt str "gitea" "Database user";

    # User and group configuration
    user = mkOpt str "gitea" "User to run Gitea as";
    group = mkOpt str "gitea" "Group to run Gitea as";

    # Service configuration
    disableRegistration = mkBoolOpt false "Disable user registration";
    enableLFS = mkBoolOpt true "Enable Git LFS support";
    enableActions = mkBoolOpt true "Enable Gitea Actions (CI/CD)";

    # Mail configuration
    mailer = {
      enable = mkBoolOpt false "Enable mail notifications";
      host = mkOpt str "smtp.gmail.com" "SMTP server address";
      port = mkOpt int 587 "SMTP server port";
      user = mkOpt str "" "SMTP username";
      from = mkOpt str "gitea@aicampground.com" "Sender email address";
    };

    # Vault integration
    role-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.role-id
      "Absolute path to the Vault role-id";
    secret-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.secret-id
      "Absolute path to the Vault secret-id";
    vault-path =
      mkOpt str "secret/campground/gitea"
      "The Vault path to the KV containing Gitea secrets";
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

    # Extra configuration
    extraConfig = mkOption {
      type = attrs;
      default = {};
      description = "Extra Gitea configuration";
      example = literalExpression ''
        {
          service = {
            DISABLE_REGISTRATION = true;
            REQUIRE_SIGNIN_VIEW = true;
          };
          "ui.meta" = {
            AUTHOR = "Gitea - Git with a cup of tea";
          };
        }
      '';
    };
  };

  config = mkIf cfg.enable {
    # PostgreSQL configuration
    fmf.services.postgresql = mkIf (cfg.databaseType == "postgres") {
      enable = true;
      authentication = [
        "local ${cfg.databaseName} ${cfg.databaseUser} trust"
      ];
      databases = [
        {
          name = cfg.databaseName;
          user = cfg.databaseUser;
        }
      ];
    };

    # Nginx reverse proxy
    services.nginx = {
      enable = true;
      virtualHosts.${cfg.domain} = {
        listen = [
          {
            addr = "0.0.0.0";
            port = cfg.httpPort;
          }
        ];

        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString cfg.port}";
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
          '';
        };
      };
    };

    # Gitea's stock unit enables PrivateUsers=true, which breaks writes to virtiofs-mounted paths
    # (UID/GID are remapped inside the user namespace). Disable it.
    systemd.services.gitea.serviceConfig.PrivateUsers = lib.mkForce false;

    # Gitea service configuration
    services.gitea = {
      enable = true;
      appName = cfg.appName;
      user = cfg.user;
      group = cfg.group;
      stateDir = cfg.stateDir;

      # Use native NixOS *File options where available
      database =
        {
          type = cfg.databaseType;
          host = cfg.databaseHost;
          name = cfg.databaseName;
          user = cfg.databaseUser;
        }
        // (lib.optionalAttrs (cfg.databaseType != "sqlite3") {
          passwordFile = secretPaths.dbPassword;
        });

      mailerPasswordFile = lib.mkIf cfg.mailer.enable secretPaths.smtpPassword;

      settings =
        recursiveUpdate {
          server = {
            DOMAIN = cfg.domain;
            HTTP_PORT = cfg.port;
            ROOT_URL = "https://${cfg.domain}";
            SSH_DOMAIN = cfg.domain;
            SSH_PORT = cfg.sshPort;
            START_SSH_SERVER = true;
            LFS_START_SERVER = cfg.enableLFS;

            # Use *_URI to read secrets from files (Gitea's documented method)
            # This prevents Gitea from auto-generating and persisting secrets to app.ini
            LFS_JWT_SECRET_URI = "file:${secretPaths.lfsJwtSecret}";
          };

          service = {
            DISABLE_REGISTRATION = cfg.disableRegistration;
            REQUIRE_SIGNIN_VIEW = false;
            DEFAULT_KEEP_EMAIL_PRIVATE = true;
            DEFAULT_ALLOW_CREATE_ORGANIZATION = true;
            ENABLE_NOTIFY_MAIL = cfg.mailer.enable;
          };

          repository = {
            ROOT = cfg.repositoryRoot;
            ENABLE_PUSH_CREATE_USER = true;
            DEFAULT_BRANCH = "main";
          };

          security = {
            INSTALL_LOCK = true;
            # Read secrets from files managed by Vault
            SECRET_KEY_URI = "file:${secretPaths.secretKey}";
            INTERNAL_TOKEN_URI = "file:${secretPaths.internalToken}";
          };

          oauth2 = {
            # OAuth2 JWT secret from file
            JWT_SECRET_URI = "file:${secretPaths.oauth2JwtSecret}";
          };

          session = {
            PROVIDER = "file";
          };

          log = {
            MODE = "console";
            LEVEL = "Info";
          };

          actions = mkIf cfg.enableActions {
            ENABLED = true;
          };

          mailer = mkIf cfg.mailer.enable {
            ENABLED = true;
            SMTP_ADDR = cfg.mailer.host;
            SMTP_PORT = cfg.mailer.port;
            FROM = cfg.mailer.from;
            USER = cfg.mailer.user;
          };
        }
        cfg.extraConfig;
    };

    # Copy Gitea secrets from Vault to persistent location
    systemd.services.setup-gitea-secrets = {
      description = "Copy Gitea secrets from Vault";
      wantedBy = ["multi-user.target"];
      before = ["gitea.service"];
      after = ["local-fs.target" "vault-agent-setup-gitea-secrets.service"];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
      script = ''
        set -euo pipefail

        # Ensure secrets directory exists
        install -d -m 0750 -o ${cfg.user} -g ${cfg.group} ${secretsDir}

        # Copy secrets from Vault agent
        ${optionalString (cfg.databaseType != "sqlite3") ''
          if [ -s /tmp/detsys-vault/gitea-db-password ]; then
            install -m 0600 -o ${cfg.user} -g ${cfg.group} /tmp/detsys-vault/gitea-db-password ${secretPaths.dbPassword}
          fi
        ''}

        if [ -s /tmp/detsys-vault/gitea-secret-key ]; then
          install -m 0600 -o ${cfg.user} -g ${cfg.group} /tmp/detsys-vault/gitea-secret-key ${secretPaths.secretKey}
        fi

        if [ -s /tmp/detsys-vault/gitea-internal-token ]; then
          install -m 0600 -o ${cfg.user} -g ${cfg.group} /tmp/detsys-vault/gitea-internal-token ${secretPaths.internalToken}
        fi

        if [ -s /tmp/detsys-vault/gitea-lfs-jwt-secret ]; then
          install -m 0600 -o ${cfg.user} -g ${cfg.group} /tmp/detsys-vault/gitea-lfs-jwt-secret ${secretPaths.lfsJwtSecret}
        fi

        if [ -s /tmp/detsys-vault/gitea-oauth2-jwt-secret ]; then
          install -m 0600 -o ${cfg.user} -g ${cfg.group} /tmp/detsys-vault/gitea-oauth2-jwt-secret ${secretPaths.oauth2JwtSecret}
        fi

        ${optionalString cfg.mailer.enable ''
          if [ -s /tmp/detsys-vault/gitea-smtp-password ]; then
            install -m 0600 -o ${cfg.user} -g ${cfg.group} /tmp/detsys-vault/gitea-smtp-password ${secretPaths.smtpPassword}
          fi
        ''}
      '';
    };

    # Vault agent configuration for secrets
    fmf.services.vault-agent.services.setup-gitea-secrets = {
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
          files =
            (optionalAttrs (cfg.databaseType != "sqlite3") {
              "gitea-db-password" = {
                text = ''
                  {{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.db_password }}{{ else }}{{ .Data.data.db_password }}{{ end }}{{ end }}
                '';
                permissions = "0600";
                change-action = "restart";
              };
            })
            // {
              "gitea-secret-key" = {
                text = ''
                  {{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.secret_key }}{{ else }}{{ .Data.data.secret_key }}{{ end }}{{ end }}
                '';
                permissions = "0600";
                change-action = "restart";
              };
              "gitea-internal-token" = {
                text = ''
                  {{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.internal_token }}{{ else }}{{ .Data.data.internal_token }}{{ end }}{{ end }}
                '';
                permissions = "0600";
                change-action = "restart";
              };

              "gitea-lfs-jwt-secret" = {
                text = ''
                  {{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.lfs_jwt_secret }}{{ else }}{{ .Data.data.lfs_jwt_secret }}{{ end }}{{ end }}
                '';
                permissions = "0600";
                change-action = "restart";
              };
              "gitea-oauth2-jwt-secret" = {
                text = ''
                  {{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.oauth2_jwt_secret }}{{ else }}{{ .Data.data.oauth2_jwt_secret }}{{ end }}{{ end }}
                '';
                permissions = "0600";
                change-action = "restart";
              };
            }
            // optionalAttrs cfg.mailer.enable {
              "gitea-smtp-password" = {
                text = ''
                  {{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.smtp_password }}{{ else }}{{ .Data.data.smtp_password }}{{ end }}{{ end }}
                '';
                permissions = "0600";
                change-action = "restart";
              };
            };
        };
      };
    };

    # Firewall configuration
    networking.firewall.allowedTCPPorts = [
      cfg.httpPort
      cfg.sshPort
    ];

    # System dependencies
    systemd.tmpfiles.rules = [
      "d ${cfg.stateDir} 0755 ${cfg.user} ${cfg.group} -"
      "d ${cfg.repositoryRoot} 0755 ${cfg.user} ${cfg.group} -"
      "d ${cfg.stateDir}/custom/conf 0750 ${cfg.user} ${cfg.group} -"
      "d ${secretsDir} 0750 ${cfg.user} ${cfg.group} -"
      "f ${cfg.stateDir}/custom/conf/app.ini 0640 ${cfg.user} ${cfg.group} -"
    ];
  };
}
