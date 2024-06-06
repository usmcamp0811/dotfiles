{ options, config, lib, ... }:
with lib;
with lib.campground;
let cfg = config.campground.services.loki;
in {
  options.campground.services.loki = with types; {
    enable = mkBoolOpt false "Enable Loki";
    httpListenPort = mkOption {
      type = int;
      default = 3030;
      description = "The port Loki listens on for HTTP requests";
    };
    httpListenAddress = mkOption {
      type = str;
      default = "0.0.0.0";
      description =
        "The IP address or hostname Loki listens on for HTTP requests";
    };
    authEnabled = mkBoolOption {
      default = false;
      description = "Enable authentication";
    };
    ingester = mkOption {
      type = attrs;
      default = {
        lifecycler = {
          address = "127.0.0.1";
          ring = {
            kvstore = { store = "inmemory"; };
            replication_factor = 1;
          };
        };
        chunk_idle_period = "1h";
        max_chunk_age = "1h";
        chunk_target_size = 999999;
        chunk_retain_period = "30s";
        max_transfer_retries = 0;
      };
      description = "Configuration for the ingester";
    };
    schemaConfig = mkOption {
      type = attrs;
      default = {
        configs = [{
          from = "2022-06-06";
          store = "boltdb-shipper";
          object_store = "filesystem";
          schema = "v11";
          index = {
            prefix = "index_";
            period = "24h";
          };
        }];
      };
      description = "Schema configuration";
    };
    storageConfig = mkOption {
      type = attrs;
      default = {
        boltdb_shipper = {
          active_index_directory = "/var/lib/loki/boltdb-shipper-active";
          cache_location = "/var/lib/loki/boltdb-shipper-cache";
          cache_ttl = "24h";
          shared_store = "filesystem";
        };
        filesystem = { directory = "/var/lib/loki/chunks"; };
      };
      description = "Storage configuration";
    };
    limitsConfig = mkOption {
      type = attrs;
      default = {
        reject_old_samples = true;
        reject_old_samples_max_age = "168h";
      };
      description = "Limits configuration";
    };
    chunkStoreConfig = mkOption {
      type = attrs;
      default = { max_look_back_period = "0s"; };
      description = "Chunk store configuration";
    };
    tableManager = mkOption {
      type = attrs;
      default = {
        retention_deletes_enabled = false;
        retention_period = "0s";
      };
      description = "Table manager configuration";
    };
    compactor = mkOption {
      type = attrs;
      default = {
        working_directory = "/var/lib/loki";
        shared_store = "filesystem";
        compactor_ring = { kvstore = { store = "inmemory"; }; };
      };
      description = "Compactor configuration";
    };
  };

  config = mkIf cfg.enable {
    services.loki = {
      enable = true;
      configuration = {
        server.http_listen_address = cfg.httpListenAddress;
        server.http_listen_port = cfg.httpListenPort;
        auth_enabled = cfg.authEnabled;

        ingester = cfg.ingester;

        schema_config = cfg.schemaConfig;

        storage_config = cfg.storageConfig;

        limits_config = cfg.limitsConfig;

        chunk_store_config = cfg.chunkStoreConfig;

        table_manager = cfg.tableManager;

        compactor = cfg.compactor;
      };
      # user, group, dataDir, extraFlags, (configFile)
    };
  };
}
