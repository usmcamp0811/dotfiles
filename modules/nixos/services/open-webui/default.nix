{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.services.open-webui;
in {
  options.campground.services.open-webui = with types; {
    enable = mkBoolOpt false "Enable Open-WebUI.";

    stateDir = mkOption {
      type = types.str;
      default = "/var/lib/open-webui";
      description = ''
        Directory for Open-WebUI state files.
      '';
    };

    port = mkOption {
      type = types.int;
      default = 18580;
      description = ''
        The port on which Open-WebUI listens.
      '';
    };

    package = mkOption {
      type = types.package;
      default = pkgs.open-webui;
      description = ''
        The package to be used for Open-WebUI service.
      '';
    };

    openFirewall = mkBoolOpt false "Open firewall for Open-WebUI.";

    host = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = ''
        The host address for Open-WebUI.
      '';
    };

    environmentFile = mkOption {
      type = types.nullOr types.str;
      default = "/var/lib/open-webui/creds";
      description = ''
        Path to a file containing environment variables for the Open-WebUI service.
      '';
    };

    environment = mkOption {
      type = types.attrsOf types.str;
      default = {
        ANONYMIZED_TELEMETRY = "False";
        DO_NOT_TRACK = "True";
        SCARF_NO_ANALYTICS = "True";
        # VECTOR_DB = "chroma";
        # CHROMA_TENANT = "campground";
        # CHROMA_DATABASE = "campground";
        # CHROMA_HTTP_HOST = "lucas";
        # CHROMA_HTTP_PORT = "18000";
        DOCS_DIR = "/var/lib/open-webui/docs";
        RAG_TOP_K = "5";
        RAG_RELEVANCE_THRESHOLD = "0";
        ENABLE_RAG_HYBRID_SEARCH = "True";
        RAG_EMBEDDING_ENGINE = "ollama";
      };
      description = ''
        Additional environment variables for the Open-WebUI service.
      '';

    };
    role-id = mkOpt types.str
      config.campground.services.vault-agent.settings.vault.role-id
      "Absolute path to the Vault role-id";
    secret-id = mkOpt types.str
      config.campground.services.vault-agent.settings.vault.secret-id
      "Absolute path to the Vault secret-id";
    vault-path = mkOpt types.str "secret/campground/open-webui"
      "The Vault path to the KV containing the KVs that are for each database";
    kvVersion = mkOption {
      type = types.enum [ "v1" "v2" ];
      default = "v2";
      description = "KV store version";
    };
    vault-address = mkOption {
      type = types.str;
      default = config.campground.services.vault-agent.settings.vault.address;
      description = "The address of your Vault";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.open-webuiSecrets = {
      description = "Get open-webui Secrets";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
      script = ''
        mkdir -p /var/lib/open-webui
        ${pkgs.coreutils}/bin/cp /tmp/detsys-vault/open-webui-creds /var/lib/open-webui/creds
        chmod 600 /var/lib/open-webui/creds
      '';
      wantedBy = [ "multi-user.target" ];
      before = [ "open-webui.service" ];

    };
    services.open-webui = {
      enable = true;
      stateDir = cfg.stateDir;
      port = cfg.port;
      package = cfg.package;
      openFirewall = cfg.openFirewall;
      host = cfg.host;
      environmentFile = cfg.environmentFile;
      environment = cfg.environment;
    };
    campground.services.vault-agent.services.open-webuiSecrets = {
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
            "open-webui-creds" = {
              text = ''
                ENABLE_OAUTH_SIGNUP=true
                OAUTH_MERGE_ACCOUNTS_BY_EMAIL=true
                OAUTH_PROVIDER_NAME=Campground
                OPENID_PROVIDER_URL={{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.OPENID_PROVIDER_URL }}{{ else }}{{ .Data.data.OPENID_PROVIDER_URL }}{{ end }}{{ end }}
                OAUTH_CLIENT_ID={{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.OAUTH_CLIENT_ID }}{{ else }}{{ .Data.data.OAUTH_CLIENT_ID }}{{ end }}{{ end }}
                OAUTH_CLIENT_SECRET={{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.OAUTH_CLIENT_SECRET }}{{ else }}{{ .Data.data.OAUTH_CLIENT_SECRET }}{{ end }}{{ end }}
                OAUTH_SCOPES='openid email profile'
                OPENID_REDIRECT_URI={{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.OPENID_REDIRECT_URI }}{{ else }}{{ .Data.data.OPENID_REDIRECT_URI }}{{ end }}{{ end }}
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
