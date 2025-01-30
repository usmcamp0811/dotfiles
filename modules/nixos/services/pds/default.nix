{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.services.pds;
in {
  options.campground.services.pds = with types; {
    enable = mkEnableOption "PDS";
    hostname = mkOpt types.str "pds.aicampground.com" "Hostname for PDS.";
    port = mkOpt types.int 3000 "Port for PDS service.";
    vault-path = mkOpt str "secret/campground/pds"
      "Vault path containing secrets for PDS.";
    kvVersion = mkOption {
      type = enum [ "v1" "v2" ];
      default = "v2";
      description = "Vault KV store version.";
    };
    vault-address = mkOption {
      type = str;
      default = config.campground.services.vault-agent.settings.vault.address;
      description = "Vault address.";
    };
  };

  config = mkIf cfg.enable {
    services.pds = {
      enable = true;
      settings = {
        PDS_PORT = cfg.port;
        PDS_HOSTNAME = cfg.hostname;
        PDS_DATA_DIRECTORY = "/var/lib/pds";
        LOG_ENABLED = true;
      };
    };

    # Vault Agent Configuration for setting PDS environment variables
    campground.services.vault-agent.services.pds = {
      settings = {
        vault.address = cfg.vault-address;
        auto_auth = {
          method = [{
            type = "approle";
            config = {
              role_id_file_path =
                config.campground.services.vault-agent.settings.vault.role-id;
              secret_id_file_path =
                config.campground.services.vault-agent.settings.vault.secret-id;
              remove_secret_id_file_after_reading = false;
            };
          }];
        };
      };
      secrets = {
        environment.templates = {
          pds = {
            text = ''
              PDS_JWT_SECRET='{{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.PDS_JWT_SECRET }}{{ else }}{{ .Data.data.PDS_JWT_SECRET }}{{ end }}{{ end }}'
              PDS_ADMIN_PASSWORD='{{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.PDS_ADMIN_PASSWORD }}{{ else }}{{ .Data.data.PDS_ADMIN_PASSWORD }}{{ end }}{{ end }}'
              PDS_PLC_ROTATION_KEY_K256_PRIVATE_KEY_HEX='{{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.PDS_PLC_ROTATION_KEY_K256_PRIVATE_KEY_HEX }}{{ else }}{{ .Data.data.PDS_PLC_ROTATION_KEY_K256_PRIVATE_KEY_HEX }}{{ end }}{{ end }}'
            '';
          };
        };
      };
    };
  };
}
