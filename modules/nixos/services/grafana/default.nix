{ lib, config, ... }:
with lib;
with lib.campground;
let cfg = config.campground.services.grafana;
in {
  options.campground.services.grafana = with types; {
    enable = mkBoolOpt false "Enable an Grafana;";
    port = mkOpt int 7443 "Port to Host the grafana server on.";
    datasources = mkOption {
      type = types.listOf (types.attrsOf types.str);
      description = "A list of datasources.";
      default = [ ];
    };
    domain = mkOpt str "grafana.lan.aicampground.com"
      "Domain to Host the grafana server on.";

    role-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.role-id
      "Absolute path to the Vault role-id";
    secret-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.secret-id
      "Absolute path to the Vault secret-id";
    vault-path = mkOpt str "secret/campground/grafana"
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
    services.grafana = {
      enable = true;
      provision = {
        enable = true;
        datasources = cfg.datasources;
      };
      settings = {
        security = {
          admin_user = "$__env{ADMIN_USER}";
          admin_password = "$__env{ADMIN_PASSWORD}";
        };
        server = {
          # Listening Address
          http_addr = "0.0.0.0";
          # and Port
          http_port = cfg.port;
          # Grafana needs to know on which domain and URL it's running
          domain = cfg.domain;
          serve_from_sub_path = true;
        };
      };
    };

    networking.firewall.allowedTCPPorts = [ cfg.port ];

    campground.services.vault-agent.services.grafana = {
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
        grafana = {
          text = ''
            {{ with secret "${cfg.vault-path}" }}
            ADMIN_USER='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.ADMIN_USER }}{{ else }}{{ .Data.data.ADMIN_USER }}{{ end }}'
            ADMIN_PASSWORD='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.ADMIN_PASSWORD }}{{ else }}{{ .Data.data.ADMIN_PASSWORD }}{{ end }}'

            {{ end }}
          '';
        };
      };
    };
  };
}
