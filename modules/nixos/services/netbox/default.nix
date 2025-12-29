{ lib
, config
, pkgs
, ...
}:
with lib;
with lib.fmf;
let
  cfg = config.fmf.services.netbox;
in
{
  options.fmf.services.netbox = with types; {
    enable = mkBoolOpt false "Enable Netbox IPAM and DCIM tool";

    package = mkOpt types.package pkgs.netbox "The Netbox package to use.";

    listenAddress = mkOpt types.str "[::1]" "Address to listen on.";
    port = mkOpt types.port 8001 "Port to listen on.";

    secretKeyFile = mkOpt (types.nullOr types.path) null
      "Path to a file containing the secret key (minimum 50 characters). If null, one will be generated.";

    dataDir = mkOpt types.path "/var/lib/netbox"
      "Directory where NetBox stores static files and media.";

    plugins = mkOption {
      type = types.functionTo (types.listOf types.package);
      default = ps: [ ];
      description = "Extra Python packages to make available to Netbox for plugins.";
      example = literalExpression "ps: with ps; [ netbox-topology-views netbox-dns ]";
    };

    settings = mkOption {
      type = types.attrs;
      default = { };
      description = "Netbox configuration as an attribute set.";
      example = literalExpression ''
        {
          ALLOWED_HOSTS = [ "*" ];
          PLUGINS = [ "netbox_topology_views" ];
        }
      '';
    };

    nginx = {
      enable = mkBoolOpt false "Enable Nginx reverse proxy for Netbox.";

      host = mkOpt (types.nullOr types.str) null "The host to serve Netbox on.";

      listen = lib.mkOption {
        type = lib.types.nullOr (lib.types.attrsOf lib.types.str);
        default = null;
        description = ''
          Nginx listen config for the virtual host. Example:
          `{ addr = "0.0.0.0"; port = "8080"; }`
        '';
      };

      forceSSL = mkOption {
        type = types.bool;
        default = false;
        description = "Whether or not to force the use of SSL.";
      };
    };

    acme = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description =
          "Whether or not to automatically fetch and configure SSL certs.";
      };
    };

    database = {
      host = mkOpt types.str "/run/postgresql" "PostgreSQL host or unix socket.";
      port = mkOpt types.int 5432 "PostgreSQL port.";
      name = mkOpt types.str "netbox" "Name of the Netbox database.";
      user = mkOpt types.str "netbox" "PostgreSQL user for Netbox.";
    };

    redis = {
      host = mkOpt types.str "localhost" "Redis host.";
      port = mkOpt types.int 6379 "Redis port.";
    };

    role-id = mkOpt (types.nullOr str) null
      "Absolute path to the Vault role-id for secrets management.";
    secret-id = mkOpt (types.nullOr str) null
      "Absolute path to the Vault secret-id for secrets management.";
    vault-path = mkOpt str "secret/campground/netbox"
      "The Vault path to the KV containing the secrets for Netbox.";
    kvVersion = mkOption {
      type = enum [ "v1" "v2" ];
      default = "v2";
      description = "KV store version";
    };
    vault-address = mkOption {
      type = nullOr str;
      default = if config.fmf.services.vault-agent.settings ? vault then
        config.fmf.services.vault-agent.settings.vault.address
      else
        null;
      description = "The address of your Vault";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.nginx.enable -> cfg.nginx.host != null;
        message = "fmf.services.netbox.nginx.host must be set when nginx is enabled.";
      }
      {
        assertion = cfg.nginx.forceSSL -> cfg.acme.enable;
        message =
          "fmf.services.netbox.nginx.forceSSL requires setting fmf.services.netbox.acme.enable to true.";
      }
    ];

    # Enable PostgreSQL for Netbox
    fmf.services.postgresql = {
      enable = true;
      enableTCPIP = mkDefault false;
      backupEnable = mkDefault true;
      backupLocation = mkDefault "/persist/postgresqlBackups/";
      databases = [{
        name = cfg.database.name;
        user = cfg.database.user;
      }];
    };

    # Enable Redis for Netbox
    services.redis.servers.netbox = {
      enable = true;
      port = cfg.redis.port;
      bind = cfg.redis.host;
    };

    # Use the upstream NixOS Netbox module
    services.netbox = {
      enable = true;
      package = cfg.package;
      listenAddress = cfg.listenAddress;
      port = cfg.port;
      secretKeyFile = if cfg.secretKeyFile != null then
        cfg.secretKeyFile
      else
        "/var/lib/netbox/secret-key";
      dataDir = cfg.dataDir;
      plugins = cfg.plugins;
      settings = mkMerge [
        {
          DATABASE = {
            NAME = cfg.database.name;
            USER = cfg.database.user;
            HOST = cfg.database.host;
            PORT = cfg.database.port;
          };
          REDIS = {
            default = {
              HOST = cfg.redis.host;
              PORT = cfg.redis.port;
            };
            caching = {
              HOST = cfg.redis.host;
              PORT = cfg.redis.port;
            };
          };
        }
        cfg.settings
      ];
    };

    # Generate secret key if not provided
    systemd.services.netbox-generate-secret-key = mkIf (cfg.secretKeyFile == null) {
      description = "Generate Netbox secret key";
      wantedBy = [ "netbox.service" ];
      before = [ "netbox.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "netbox";
        Group = "netbox";
      };
      script = ''
        if [ ! -f /var/lib/netbox/secret-key ]; then
          mkdir -p /var/lib/netbox
          ${pkgs.openssl}/bin/openssl rand -base64 60 > /var/lib/netbox/secret-key
          chmod 600 /var/lib/netbox/secret-key
        fi
      '';
    };

    # Configure Nginx if enabled
    services.nginx = mkIf cfg.nginx.enable {
      enable = true;
      user = "netbox";
      recommendedProxySettings = true;

      virtualHosts."${cfg.nginx.host}" = {
        listen = lib.optional (cfg.nginx.listen != null) cfg.nginx.listen;
        enableACME = cfg.acme.enable;
        forceSSL = cfg.nginx.forceSSL;

        locations."/" = {
          proxyPass = "http://${cfg.listenAddress}:${toString cfg.port}";
          proxyWebsockets = true;
        };

        locations."/static/" = {
          alias = "${cfg.dataDir}/static/";
        };

        locations."/media/" = {
          alias = "${cfg.dataDir}/media/";
        };
      };
    };

    # Vault integration for secrets (optional)
    fmf.services.vault-agent.services.netbox = mkIf (cfg.role-id != null && cfg.secret-id != null) {
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
      secrets.environment.templates = {
        netbox = {
          text = ''
            DATABASE_PASSWORD={{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.DATABASE_PASSWORD }}{{ else }}{{ .Data.data.DATABASE_PASSWORD }}{{ end }}{{ end }}
            SECRET_KEY={{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.SECRET_KEY }}{{ else }}{{ .Data.data.SECRET_KEY }}{{ end }}{{ end }}
          '';
        };
      };
    };
  };
}
