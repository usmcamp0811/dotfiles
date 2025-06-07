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
      private_key = mkOption { type = types.path; };
    };
  };

  config = mkIf cfg.enable {
    services.crystal-forge = {
      inherit
        (cfg)
        configPath
        database
        server
        client
        ;
    };
  };
}
