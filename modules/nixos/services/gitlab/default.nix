{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.services.gitlab;
in {
  options.campground.services.gitlab = with types; {
    enable = mkBoolOpt false "Enable GitLab;";

    # Basic configuration
    host = mkOpt str "gitlab.lan.aicampground.com" "GitLab hostname";
    port = mkOpt int 8443 "Port to serve GitLab on";
    httpsPort = mkOpt int 443 "HTTPS port for GitLab";
    sshPort = mkOpt int 2222 "SSH port for GitLab";

    # Database configuration
    databaseHost = mkOpt str "/run/postgresql" "Database host (socket path for local PostgreSQL)";
    databaseName = mkOpt str "gitlab" "Database name";
    databaseUsername = mkOpt str "gitlab" "Database username";

    # Redis configuration
    redisHost = mkOpt str "127.0.0.1" "Redis host";
    redisPort = mkOpt int 6379 "Redis port";

    # Storage configuration
    statePath = mkOpt str "/var/lib/gitlab/state" "GitLab state directory";
    backupPath = mkOpt str "/var/lib/gitlab/backup" "GitLab backup directory";
    repositoryPath = mkOpt str "/var/lib/gitlab/repositories" "Git repositories path";

    # Package and user configuration
    package = mkOpt package pkgs.gitlab-ee "GitLab package to use";
    user = mkOpt str "gitlab" "User to run GitLab as";
    group = mkOpt str "gitlab" "Group to run GitLab as";

    # GitLab configuration
    initialRootEmail = mkOpt str "admin@aicampground.com" "Initial root user email";
    railsEnvironment = mkOpt str "production" "Rails environment";

    # SMTP configuration (optional)
    smtp = {
      enable = mkBoolOpt false "Enable SMTP configuration";
      address = mkOpt str "smtp.gmail.com" "SMTP server address";
      port = mkOpt int 587 "SMTP server port";
      username = mkOpt str "" "SMTP username";
      authentication = mkOpt str "login" "SMTP authentication method";
      enableStartTLSAuto = mkBoolOpt true "Enable STARTTLS auto";
      tls = mkBoolOpt false "Enable TLS";
      domain = mkOpt str "aicampground.com" "SMTP domain";
    };

    # Backup configuration
    backup = {
      enable = mkBoolOpt true "Enable GitLab backups";
      startAt = mkOpt str "02:00" "When to start backups";
      keep = mkOpt int 7 "Number of backups to keep";
    };

    # Registry configuration
    registry = {
      enable = mkBoolOpt false "Enable GitLab Container Registry";
      host = mkOpt str "registry.${cfg.host}" "Registry hostname";
      port = mkOpt int 5555 "Registry port";
      certFile = mkOpt str "/var/lib/gitlab/registry.crt" "Registry certificate file";
      keyFile = mkOpt str "/var/lib/gitlab/registry.key" "Registry key file";
    };

    # Pages configuration
    pages = {
      enable = mkBoolOpt false "Enable GitLab Pages";
      host = mkOpt str "pages.${cfg.host}" "Pages hostname";
      port = mkOpt int 8090 "Pages port";
    };

    # Vault integration
    role-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.role-id
      "Absolute path to the Vault role-id";
    secret-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.secret-id
      "Absolute path to the Vault secret-id";
    vault-path =
      mkOpt str "secret/campground/gitlab"
      "The Vault path to the KV containing GitLab secrets";
    kvVersion = mkOption {
      type = enum ["v1" "v2"];
      default = "v2";
      description = "KV store version";
    };
    vault-address = mkOption {
      type = str;
      default = config.campground.services.vault-agent.settings.vault.address;
      description = "The address of your Vault";
    };

    # Extra configuration
    extraConfig = mkOption {
      type = attrs;
      default = {};
      description = "Extra GitLab configuration";
      example = literalExpression ''
        {
          gitlab = {
            time_zone = "America/Chicago";
            default_projects_features = {
              issues = true;
              merge_requests = true;
              wiki = true;
              snippets = true;
            };
          };
          omniauth = {
            enabled = true;
            allow_single_sign_on = ["saml"];
            block_auto_created_users = false;
          };
        }
      '';
    };
  };

  config = mkIf cfg.enable {
    # User and group configuration
    users = {
      users = {
        ${cfg.user} = {
          description = "GitLab service user";
          group = cfg.group;
          isSystemUser = true;
          home = cfg.statePath;
          createHome = true;
        };
      };
      groups = {
        ${cfg.group} = {};
      };
    };

    # PostgreSQL configuration
    campground.services.postgresql = {
      enable = true;
      enableTCPIP = false;
      authentication = [
        "local ${cfg.databaseName} ${cfg.databaseUsername} trust"
      ];
      databases = [
        {
          name = cfg.databaseName;
          user = cfg.databaseUsername;
        }
      ];
    };

    # Redis configuration
    services.redis.servers."" = {
      enable = true;
      port = cfg.redisPort;
      bind = cfg.redisHost;
    };

    # Nginx reverse proxy
    services.nginx = {
      enable = true;
      virtualHosts.${cfg.host} = {
        listen = [
          {
            addr = "0.0.0.0";
            port = cfg.port;
          }
        ];
        locations."/" = {
          proxyPass = "http://unix:/run/gitlab/gitlab-workhorse.socket";
          extraConfig = ''
            proxy_set_header Host $http_host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_cache_bypass $http_upgrade;
            proxy_redirect off;
          '';
        };
      };
    };

    # GitLab service configuration
    services.gitlab = {
      enable = true;
      host = cfg.host;
      port = cfg.httpsPort;
      user = cfg.user;
      group = cfg.group;
      statePath = cfg.statePath;
      backupPath = cfg.backupPath;
      repositoryRoot = cfg.repositoryPath;
      databaseHost = cfg.databaseHost;
      databaseName = cfg.databaseName;
      databaseUsername = cfg.databaseUsername;
      databasePasswordFile = "/var/lib/vault/gitlab-db-password";
      initialRootEmail = cfg.initialRootEmail;
      initialRootPasswordFile = "/var/lib/vault/gitlab-root-password";
      secrets = {
        secretFile = "/var/lib/vault/gitlab-secret";
        otpFile = "/var/lib/vault/gitlab-otp";
        dbFile = "/var/lib/vault/gitlab-db-secret";
        jwsFile = "/var/lib/vault/gitlab-jws";
      };

      smtp = mkIf cfg.smtp.enable {
        enable = true;
        address = cfg.smtp.address;
        port = cfg.smtp.port;
        username = cfg.smtp.username;
        passwordFile = "/var/lib/vault/gitlab-smtp-password";
        domain = cfg.smtp.domain;
        authentication = cfg.smtp.authentication;
        enableStartTLSAuto = cfg.smtp.enableStartTLSAuto;
        tls = cfg.smtp.tls;
      };

      registry = mkIf cfg.registry.enable {
        enable = true;
        host = cfg.registry.host;
        port = cfg.registry.port;
        certFile = cfg.registry.certFile;
        keyFile = cfg.registry.keyFile;
      };

      pages = mkIf cfg.pages.enable {
        enable = true;
        host = cfg.pages.host;
        port = cfg.pages.port;
      };

      extraConfig =
        recursiveUpdate {
          gitlab = {
            time_zone = "America/Chicago";
            default_projects_features = {
              issues = true;
              merge_requests = true;
              wiki = true;
              snippets = true;
              builds = true;
              container_registry = cfg.registry.enable;
            };
          };
          production = {
            redis = {
              host = cfg.redisHost;
              port = cfg.redisPort;
            };
          };
        }
        cfg.extraConfig;
    };

    # Backup service
    systemd.services.gitlab-backup = mkIf cfg.backup.enable {
      description = "GitLab backup service";
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = "${cfg.package}/bin/gitlab-backup create SKIP=registry";
        ExecStartPost = "${pkgs.bash}/bin/bash -c 'find ${cfg.backupPath} -name \"*gitlab_backup.tar\" -mtime +${toString cfg.backup.keep} -delete'";
      };
    };

    systemd.timers.gitlab-backup = mkIf cfg.backup.enable {
      description = "GitLab backup timer";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = cfg.backup.startAt;
        Persistent = true;
      };
    };

    # Setup GitLab secrets from Vault
    systemd.services.setup-gitlab-secrets = {
      description = "Setup GitLab secrets from Vault";
      wantedBy = ["multi-user.target"];
      before = ["gitlab.service"];
      after = ["postgresql.service"];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
      script = ''
        mkdir -p /var/lib/vault

        # Copy secrets from Vault agent
        cp /tmp/detsys-vault/gitlab-db-password /var/lib/vault/
        cp /tmp/detsys-vault/gitlab-root-password /var/lib/vault/
        cp /tmp/detsys-vault/gitlab-secret /var/lib/vault/
        cp /tmp/detsys-vault/gitlab-otp /var/lib/vault/
        cp /tmp/detsys-vault/gitlab-db-secret /var/lib/vault/
        cp /tmp/detsys-vault/gitlab-jws /var/lib/vault/
        ${optionalString cfg.smtp.enable "cp /tmp/detsys-vault/gitlab-smtp-password /var/lib/vault/"}

        # Set correct permissions
        chown ${cfg.user}:${cfg.group} /var/lib/vault/gitlab-*
        chmod 600 /var/lib/vault/gitlab-*
      '';
    };

    # Firewall configuration
    networking.firewall.allowedTCPPorts =
      [
        cfg.port
        cfg.sshPort
      ]
      ++ optionals cfg.registry.enable [cfg.registry.port]
      ++ optionals cfg.pages.enable [cfg.pages.port];

    # Vault agent configuration for secrets
    campground.services.vault-agent.services.setup-gitlab-secrets = {
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
            {
              "gitlab-db-password" = {
                text = ''
                  {{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.db_password }}{{ else }}{{ .Data.data.db_password }}{{ end }}{{ end }}
                '';
                permissions = "0600";
                change-action = "restart";
              };
              "gitlab-root-password" = {
                text = ''
                  {{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.root_password }}{{ else }}{{ .Data.data.root_password }}{{ end }}{{ end }}
                '';
                permissions = "0600";
                change-action = "restart";
              };
              "gitlab-secret" = {
                text = ''
                  {{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.secret_key_base }}{{ else }}{{ .Data.data.secret_key_base }}{{ end }}{{ end }}
                '';
                permissions = "0600";
                change-action = "restart";
              };
              "gitlab-otp" = {
                text = ''
                  {{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.otp_key_base }}{{ else }}{{ .Data.data.otp_key_base }}{{ end }}{{ end }}
                '';
                permissions = "0600";
                change-action = "restart";
              };
              "gitlab-db-secret" = {
                text = ''
                  {{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.db_key_base }}{{ else }}{{ .Data.data.db_key_base }}{{ end }}{{ end }}
                '';
                permissions = "0600";
                change-action = "restart";
              };
              "gitlab-jws" = {
                text = ''
                  {{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.jws_private_key }}{{ else }}{{ .Data.data.jws_private_key }}{{ end }}{{ end }}
                '';
                permissions = "0600";
                change-action = "restart";
              };
            }
            // optionalAttrs cfg.smtp.enable {
              "gitlab-smtp-password" = {
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

    # System dependencies
    systemd.tmpfiles.rules = [
      "d ${cfg.statePath} 0755 ${cfg.user} ${cfg.group} -"
      "d ${cfg.backupPath} 0755 ${cfg.user} ${cfg.group} -"
      "d ${cfg.repositoryPath} 0755 ${cfg.user} ${cfg.group} -"
      "d /var/lib/vault 0755 root root -"
    ];
  };
}
