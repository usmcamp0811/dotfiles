# /path/to/modules/netbox.nix
{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.netbox;

  effectiveListen = cfg.listenAddress;
  loopbackUpstream = "127.0.0.1"; # for nginx proxying regardless of listenAddress formatting
in {
  options.fmf.services.netbox = with types; {
    enable = mkBoolOpt false "Enable NetBox IPAM/DCIM";

    package = mkOpt types.package pkgs.netbox "The NetBox package to use.";

    # Safer default: bind locally only. In your VM config set 0.0.0.0 if you want remote access.
    listenAddress = mkOpt types.str "127.0.0.1" "Address NetBox binds to.";
    port = mkOpt types.port 8001 "Port NetBox listens on.";

    openFirewall = mkBoolOpt false "Open the firewall for the NetBox port when nginx is not used.";

    secretKeyFile =
      mkOpt (types.nullOr types.path) null
      "Path to secret key file. If null, generated under dataDir.";

    apiTokenPeppersFile =
      mkOpt (types.nullOr types.path) null
      "Path to NetBox API token peppers file. If null, generated under dataDir.";

    apiTokenPeppersFile =
      mkOpt (types.nullOr types.path) null
      "Path to NetBox API token peppers file. If null, generated under dataDir.";

    dataDir =
      mkOpt types.path "/var/lib/netbox"
      "Directory where NetBox stores static files/media and generated secret key.";

    plugins = mkOption {
      type = types.functionTo (types.listOf types.package);
      default = ps: [];
      description = "Extra Python packages to make available to NetBox for plugins.";
      example = literalExpression "ps: with ps; [ netbox-topology-views netbox-dns ]";
    };

    settings = mkOption {
      type = types.attrs;
      default = {};
      description = "NetBox configuration as an attribute set.";
    };

    nginx = {
      enable = mkBoolOpt false "Enable Nginx reverse proxy for NetBox.";
      host = mkOpt (types.nullOr types.str) null "Hostname for the vhost.";
      listen = mkOption {
        type = types.nullOr (types.attrsOf types.str);
        default = null;
        description = "Nginx listen attrset, e.g. { addr = \"0.0.0.0\"; port = \"8080\"; }";
      };
      forceSSL = mkOption {
        type = types.bool;
        default = false;
        description = "Force SSL (requires acme.enable).";
      };
    };

    acme.enable = mkOption {
      type = types.bool;
      default = false;
      description = "Automatically fetch and configure TLS certs (nginx).";
    };

    database = {
      host = mkOpt types.str "/run/postgresql" "PostgreSQL host or unix socket path.";
      port = mkOpt types.int 5432 "PostgreSQL port.";
      name = mkOpt types.str "netbox" "Database name.";
      user = mkOpt types.str "netbox" "Database user.";
    };

    redis = {
      host = mkOpt types.str "127.0.0.1" "Redis host.";
      port = mkOpt types.int 6379 "Redis port.";
    };

    role-id = mkOpt (types.nullOr str) null "Vault role-id file path.";
    secret-id = mkOpt (types.nullOr str) null "Vault secret-id file path.";
    vault-path = mkOpt str "secret/campground/netbox" "Vault KV path for NetBox secrets.";
    kvVersion = mkOption {
      type = enum ["v1" "v2"];
      default = "v2";
      description = "Vault KV version.";
    };
    vault-address = mkOption {
      type = nullOr str;
      default =
        if config.fmf.services.vault-agent.settings ? vault
        then config.fmf.services.vault-agent.settings.vault.address
        else null;
      description = "Vault address.";
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
        message = "fmf.services.netbox.nginx.forceSSL requires fmf.services.netbox.acme.enable = true.";
      }
    ];

    # Postgres/Redis (you already do this; keeping it)
    fmf.services.postgresql = {
      enable = true;
      enableTCPIP = mkDefault false;
      backupEnable = mkDefault true;
      backupLocation = mkDefault "/persist/postgresqlBackups/";
      databases = [
        {
          name = cfg.database.name;
          user = cfg.database.user;
        }
      ];
    };

    services.redis.servers.netbox = {
      enable = true;
      port = cfg.redis.port;
      bind = cfg.redis.host;
    };

    # Make sure NetBox has a secret key file available.
    systemd.services.netbox-generate-secret-key = mkIf (cfg.secretKeyFile == null) {
      description = "Generate NetBox secret key";
      before = ["netbox.service"];
      wantedBy = ["netbox.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "netbox";
        Group = "netbox";
      };
      script = ''
        keyFile="${cfg.dataDir}/secret-key"
        if [ ! -f "$keyFile" ]; then
          install -d -m 0750 -o netbox -g netbox "${cfg.dataDir}"
          ${pkgs.openssl}/bin/openssl rand -base64 60 > "$keyFile"
          chmod 600 "$keyFile"
          chown netbox:netbox "$keyFile"
        fi
      '';
    };

    systemd.services.netbox-generate-api-token-peppers = mkIf (cfg.apiTokenPeppersFile == null) {
      description = "Generate NetBox API token peppers file";
      before = ["netbox.service"];
      wantedBy = ["netbox.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "netbox";
        Group = "netbox";
      };
      script = ''
        peppersFile="${cfg.dataDir}/api-token-peppers"
        if [ ! -f "$peppersFile" ]; then
          install -d -m 0750 -o netbox -g netbox "${cfg.dataDir}"
          ${pkgs.openssl}/bin/openssl rand -hex 32 > "$peppersFile"
          chmod 600 "$peppersFile"
          chown netbox:netbox "$peppersFile"
        fi
      '';
    };

    systemd.services.netbox-generate-api-token-peppers = mkIf (cfg.apiTokenPeppersFile == null) {
      description = "Generate NetBox API token peppers file";
      before = ["netbox.service"];
      wantedBy = ["netbox.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "netbox";
        Group = "netbox";
      };
      script = ''
        peppersFile="${cfg.dataDir}/api-token-peppers"
        if [ ! -f "$peppersFile" ]; then
          install -d -m 0750 -o netbox -g netbox "${cfg.dataDir}"
          ${pkgs.openssl}/bin/openssl rand -hex 32 > "$peppersFile"
          chmod 600 "$peppersFile"
          chown netbox:netbox "$peppersFile"
        fi
      '';
    };

    # Upstream NixOS NetBox module
    services.netbox = {
      enable = true;
      package = cfg.package;
      listenAddress = effectiveListen;
      port = cfg.port;

      secretKeyFile =
        if cfg.secretKeyFile != null
        then cfg.secretKeyFile
        else "${cfg.dataDir}/secret-key";

      apiTokenPeppersFile =
        if cfg.apiTokenPeppersFile != null
        then cfg.apiTokenPeppersFile
        else "${cfg.dataDir}/api-token-peppers";

      apiTokenPeppersFile =
        if cfg.apiTokenPeppersFile != null
        then cfg.apiTokenPeppersFile
        else "${cfg.dataDir}/api-token-peppers";

      dataDir = cfg.dataDir;
      plugins = cfg.plugins;

      settings = mkMerge [
        # sane defaults so you can actually hit it
        {
          ALLOWED_HOSTS = ["*"];

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

    # NetBox first-start can take a while (migrations/static collection)
    systemd.services.netbox.serviceConfig.TimeoutStartSec = mkForce "15min";
    systemd.services.netbox-worker.serviceConfig.TimeoutStartSec = mkForce "15min";
    systemd.services.netbox-housekeeping.serviceConfig.TimeoutStartSec = mkForce "15min";

    # If you want direct access without nginx, you must open the port (and bind non-loopback).
    networking.firewall.allowedTCPPorts =
      mkIf (cfg.openFirewall && !cfg.nginx.enable) [cfg.port];

    # Nginx proxy (optional)
    services.nginx = mkIf cfg.nginx.enable {
      enable = true;
      recommendedProxySettings = true;

      virtualHosts."${cfg.nginx.host}" = {
        listen = lib.optional (cfg.nginx.listen != null) cfg.nginx.listen;
        enableACME = cfg.acme.enable;
        forceSSL = cfg.nginx.forceSSL;

        locations."/" = {
          proxyPass = "http://${loopbackUpstream}:${toString cfg.port}";
          proxyWebsockets = true;
        };

        locations."/static/" = {alias = "${cfg.dataDir}/static/";};
        locations."/media/" = {alias = "${cfg.dataDir}/media/";};
      };
    };

    # Vault integration (optional) — NOTE: this only *writes* a template; you still must
    # actually wire these env vars into NetBox if you want them used.
    fmf.services.vault-agent.services.netbox = mkIf (cfg.role-id != null && cfg.secret-id != null) {
      settings = {
        vault.address = cfg.vault-address;
        auto_auth.method = [
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

      secrets.environment.templates.netbox = {
        text = ''
          DATABASE_PASSWORD={{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.DATABASE_PASSWORD }}{{ else }}{{ .Data.data.DATABASE_PASSWORD }}{{ end }}{{ end }}
          SECRET_KEY={{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.SECRET_KEY }}{{ else }}{{ .Data.data.SECRET_KEY }}{{ end }}{{ end }}
        '';
      };
    };
  };
}
