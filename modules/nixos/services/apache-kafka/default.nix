{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.services.apache-kafka;
in {
  options.campground.services.apache-kafka = with types; {
    enable = mkBoolOpt false "Enable Kafka;";

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = {
        "broker.id" = 1;
        "log.dirs" = [ "/var/lib/kafka/logs" ];
        "listeners" = [ "PLAINTEXT://:9092" ];
        "num.network.threads" = 3;
        "num.io.threads" = 8;
        "socket.send.buffer.bytes" = 102400;
        "socket.receive.buffer.bytes" = 102400;
        "socket.request.max.bytes" = 104857600;
        "zookeeper.connect" = "localhost:2181";
      };
      example = {
        "broker.id" = 1;
        "log.dirs" = [ "/var/lib/kafka/logs" ];
        "listeners" = [ "PLAINTEXT://:9092" ];
        "num.network.threads" = 3;
        "num.io.threads" = 8;
        "socket.send.buffer.bytes" = 102400;
        "socket.receive.buffer.bytes" = 102400;
        "socket.request.max.bytes" = 104857600;
        "zookeeper.connect" = "localhost:2181";
      };
      description = "Kafka service settings.";
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
      enable = true; # Enables the Apache Kafka service.

      settings = cfg.settings;

      jvmOptions = [
        "-Xmx1G" # Sets the maximum size of the memory allocation pool.
        "-Xms1G" # Sets the initial memory allocation pool.
      ];
    };
  };
}
