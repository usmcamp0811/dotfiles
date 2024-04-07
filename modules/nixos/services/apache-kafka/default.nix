{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.services.apache-kafka;
in {
  options.campground.services.apache-kafka = with types; {
    enable = mkBoolOpt false "Enable Kafka;";

    settings = mkOption {
      description = lib.mdDoc ''
        [Kafka broker configuration](https://kafka.apache.org/documentation.html#brokerconfigs)
        {file}`server.properties`.

        Note that .properties files contain mappings from string to string.
        Keys with dots are NOT represented by nested attrs in these settings,
        but instead as quoted strings (ie. `settings."broker.id"`, NOT
        `settings.broker.id`).
     '';
      type = types.submodule {
        freeformType = with types; let
          primitive = oneOf [bool int str];
        in lazyAttrsOf (nullOr (either primitive (listOf primitive)));

        options = {
          "broker.id" = mkOption {
            description = lib.mdDoc "Broker ID. -1 or null to auto-allocate in zookeeper mode.";
            default = null;
            type = with types; nullOr int;
          };

          "log.dirs" = mkOption {
            description = lib.mdDoc "Log file directories.";
            # Deliberaly leave out old default and use the rewrite opportunity
            # to have users choose a safer value -- /tmp might be volatile and is a
            # slightly scary default choice.
            # default = [ "/tmp/apache-kafka" ];
            type = with types; listOf path;
          };

          "listeners" = mkOption {
            description = lib.mdDoc ''
              Kafka Listener List.
              See [listeners](https://kafka.apache.org/documentation/#brokerconfigs_listeners).
            '';
            type = types.listOf types.str;
            default = [ "PLAINTEXT://localhost:9092" ];
          };
        };
      };
    };

    clusterId = mkOption {
      description = lib.mdDoc ''
        KRaft mode ClusterId used for formatting log directories. Can be generated with `kafka-storage.sh random-uuid`
      '';
      type = with types; nullOr str;
      default = null;
    };
  };

  config = mkIf cfg.enable {
    services.apache-kafka = {
      enable = true;   
    }
  };
}
