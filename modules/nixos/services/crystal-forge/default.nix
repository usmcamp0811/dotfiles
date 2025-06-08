{ lib
, config
, pkgs
, ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.services.crystal-forge;
in
{
  options.campground.services.crystal-forge = {
    enable = mkEnableOption "Enable the Crystal Forge service(s)";
    configPath = mkOption {
      type = types.path;
      default = generatedConfigPath;
      description = "Path to the final config.toml file.";
    };
    database = {
      host = mkOption {
        type = types.str;
        default = "localhost";
      };
      user = mkOption {
        type = types.str;
        default = "crystal_forge";
      };
      password = mkOption {
        type = types.str;
        default = "password";
      };
      passwordFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Optional path to a file containing the database password. Overrides 'password'.";
      };
      dbname = mkOption {
        type = types.str;
        default = "crystal_forge";
      };
    };
    server = {
      enable = mkEnableOption "Enable the Crystal Forge Server";
      host = mkOption {
        type = types.str;
        default = "0.0.0.0";
      };
      port = mkOption {
        type = types.port;
        default = 3000;
      };
      authorized_keys = mkOption {
        type = types.attrsOf types.str;
        default = { };
      };
    };
    client = {
      enable = mkEnableOption "Enable the Crystal Forge Agent";
      server_host = mkOption {
        type = types.str;
        default = "reckless";
      };
      server_port = mkOption {
        type = types.port;
        default = 3000;
      };
    };
    role-id =
      mkOpt types.str
        config.campground.services.vault-agent.settings.vault.role-id
        "Absolute path to the Vault role-id";
    secret-id =
      mkOpt types.str
        config.campground.services.vault-agent.settings.vault.secret-id
        "Absolute path to the Vault secret-id";
    vault-path =
      mkOpt types.str "secret/campground/crystal-forge"
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
    services.crystal-forge = {
      inherit
        (cfg)
        enable
        configPath
        database
        server
        ;
      client = {
        inherit (cfg.client) server_port server_host enable;
        private_key = "/tmp/detsys-vault/${config.networking.hostName}";
      };
    };
    campground.services = {
      vault-agent = {
        services = {
          "crystal-forge-agent" = {
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
                files = {
                  "${config.networking.hostName}.key" = {
                    text = ''
                      {{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.${
                        config.networking.hostName
                      }}{{ else }}{{ .Data.data.${
                        config.networking.hostName
                      } }}{{ end }}{{ end }}'';
                    permissions = "0600";
                    change-action = "restart";
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
