{ lib, config, pkgs, inputs, ... }:
with lib;
with lib.fmf;
let cfg = config.fmf.services.immich;
in {
  options.fmf.services.immich = with types; {
    enable = mkBoolOpt false "Enable Immich;";
    mediaLocation =
      mkOpt path "/var/lib/immich" "Directory used to store media files.";
    port = mkOpt int 13001 "Port to expose Immich on";
    host = mkOpt str "0.0.0.0" "Host for Immich to listen on";
    user = mkOpt str "immich" "User to run Immich as";
    group = mkOpt str "immich" "Group to run Immich as";
    openFirewall =
      mkOpt bool false "Whether to open the Immich port in the firewall";

    database = {
      enable = mkBoolOpt true "Enable PostgreSQL for Immich";
      createDB = mkBoolOpt true "Automatically create the Immich database";
      name = mkOpt str "immich" "Name of the Immich database";
      host = mkOpt str "/run/postgresql" "PostgreSQL host or unix socket";
      port = mkOpt int 5432 "PostgreSQL port";
      user = mkOpt str "immich" "PostgreSQL user for Immich";
    };

    redis = {
      enable = mkBoolOpt true "Enable Redis for Immich";
      host = mkOpt str "/run/redis/redis.sock" "Redis host or unix socket";
      port = mkOpt int 0 "Redis port (0 to disable TCP)";
    };

    machineLearning = {
      enable = mkBoolOpt true "Enable machine learning for Immich";
      modelTTL = mkOpt str "600" "TTL for machine learning models";
    };

    # role-id =
    #   mkOpt str config.fmf.services.vault-agent.settings.vault.role-id
    #   "Absolute path to the Vault role-id";
    # secret-id =
    #   mkOpt str config.fmf.services.vault-agent.settings.vault.secret-id
    #   "Absolute path to the Vault secret-id";
    # vault-path = mkOpt str "secret/campground/immich"
    #   "The Vault path to the KV containing the KVs that are for each database";
    # kvVersion = mkOption {
    #   type = enum [ "v1" "v2" ];
    #   default = "v2";
    #   description = "KV store version";
    # };
    # vault-address = mkOption {
    #   type = str;
    #   default = config.fmf.services.vault-agent.settings.vault.address;
    #   description = "The address of your Vault";
    # };
  };

  config = mkIf cfg.enable {
    fmf.services.postgresql = {
      enable = true;
      enableTCPIP = true;
      backupEnable = true;
      backupLocation = "/persist/postgresqlBackups/";
      databases = [{
        name = "immich";
        user = "immich";
      }];
    };
    # Enable services.immich using the upstream service module
    services.immich = {
      enable = true;
      mediaLocation = cfg.mediaLocation;
      port = cfg.port;
      host = cfg.host;
      # user = cfg.user;
      # group = cfg.group;
      openFirewall = cfg.openFirewall;
      database = {
        enable = cfg.database.enable;
        # createDB = cfg.database.createDB;
        # name = cfg.database.name;
        host = cfg.database.host;
        # port = cfg.database.port;
        # user = cfg.database.user;
      };
      redis = {
        enable = cfg.redis.enable;
        # host = cfg.redis.host;
        # port = cfg.redis.port;
      };
      machine-learning = {
        enable = cfg.machineLearning.enable;
        environment = {
          MACHINE_LEARNING_MODEL_TTL = cfg.machineLearning.modelTTL;
        };
      };
      # secretsFile = cfg.secretsFile;
    };

    # # User and group setup
    # users.users.immich = mkIf (cfg.user == "immich") {
    #   isSystemUser = true;
    #   home = "/var/lib/immich";
    #   group = "immich";
    # };
    # users.groups.immich = {};

    # fmf.services.vault-agent.services.immich-server = {
    #   settings = {
    #     vault.address = cfg.vault-address;
    #     auto_auth = {
    #       method = [
    #         {
    #           type = "approle";
    #           config = {
    #             role_id_file_path = cfg.role-id;
    #             secret_id_file_path = cfg.secret-id;
    #             remove_secret_id_file_after_reading = false;
    #           };
    #         }
    #       ];
    #     };
    #   };
    #   secrets = {
    #     file = {
    #       files = {
    #         "immich.pass" = {
    #           text = ''
    #             {{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.password }}{{ else }}{{ .Data.data.password }}{{ end }}{{ end }}
    #           '';
    #           permissions = "0600";
    #           change-action = "restart";
    #         };
    #       };
    #     };
    #   };
    # };
  };
}
