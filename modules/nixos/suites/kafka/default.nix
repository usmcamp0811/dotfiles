{ host ? "", options, config, lib, pkgs, ... }:
with lib;
with lib.fmf;
let
  cfg = config.fmf.suites.kafka;
  bootstrap-server = "${cfg.kafka-lan-ip}:${builtins.toString cfg.kafka-port}";
in {
  options.fmf.suites.kafka = with types; {
    enable = mkBoolOpt false "Enable Kafka configurations.";
    interface =
      mkOpt str "eno1" "Network interface used for all Kafka services.";

    # Kafka specific options
    kafka-interface =
      mkOpt str cfg.interface "Network interface used by Kafka.";
    kafka-port = mkOpt int 9092 "Network port for the Apache Kafka server.";
    kafka-lan-ip = mkOpt str "10.8.0.72" "LAN IP address for Kafka instances.";

    # Kafka Connect specific options
    connect-server = mkBoolOpt false "Enable Kafka Connect on this server.";
    kc-interface =
      mkOpt str cfg.interface "Network interface used by Kafka Connect.";
    kc-lan-ip =
      mkOpt str "10.8.0.70" "LAN IP address for Kafka Connect instances.";
    kc-port = mkOpt int 8323 "Network port for the Kafka Connect server.";

    # Karapace specific options
    schema-server = mkBoolOpt false "Enable Karapace on this server.";
    karapace-interface =
      mkOpt str cfg.interface "Network interface used by Karapace.";
    karapace-lan-ip =
      mkOpt str "10.8.0.71" "LAN IP address for Karapace instances.";
    karapace-port = mkOpt int 8436 "Network port for the Karapace server.";

    # AKHQ UI specific options
    ui-server = mkBoolOpt false "Enable AKHQ (Apache Kafka HQ) on this server.";
    ui-port = mkOpt int 8435 "Network port for the AKHQ server.";
    ui-bootstrap-server =
      mkOpt str "webb:9092" "Bootstrap server address for AKHQ.";

    # TimescaleDB specific options
    timescale-server =
      mkBoolOpt false "Enable PostgreSQL with TimescaleDB on this server.";
    timescalePackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.postgresql16Packages.timescaledb;
      description = "TimescaleDB package for PostgreSQL.";
    };

    # Zookeeper specific options
    zookeeper-id = mkOpt int 0 "Zookeeper server ID.";
    servers = mkOption {
      type = types.lines;
      default = ''
        server.1=chesty:2888:3888
        server.2=webb:2888:3888
        server.3=daly:2888:3888
        server.4=lucas:2888:3888
      '';
      description = "Configuration lines for all Zookeeper servers.";
    };
  };

  config = mkIf cfg.enable {

    networking.firewall = { allowedTCPPorts = [ 2181 2888 3888 9092 ]; };

    fmf = {
      services = {
        keepalived = {
          enable = true;
          instances = {
            "kafka" = {
              interface = cfg.kafka-interface;
              ips = [ cfg.kafka-lan-ip ];
              state = "MASTER";
              priority = 50;
              virtualRouterId = 53;
            };
            "kafka-connect" = mkIf cfg.connect-server {
              interface = cfg.kc-interface;
              ips = [ cfg.kc-lan-ip ];
              state = "MASTER";
              priority = 50;
              virtualRouterId = 55;
            };
            "karapace" = mkIf cfg.schema-server {
              interface = cfg.karapace-interface;
              ips = [ cfg.karapace-lan-ip ];
              state = "MASTER";
              priority = 50;
              virtualRouterId = 56;
            };
          };
        };
        kafka-connect = {
          enable = cfg.connect-server;
          config = {
            "bootstrap.servers" = bootstrap-server;
            "group.id" = "connect-cluster";
            "key.converter" = "org.apache.kafka.connect.json.JsonConverter";
            "value.converter" = "org.apache.kafka.connect.json.JsonConverter";
            "key.converter.schemas.enable" = true;
            "value.converter.schemas.enable" = true;
            "offset.storage.topic" = "connect-offsets";
            "offset.storage.replication.factor" = 1;
            "config.storage.topic" = "connect-configs";
            "config.storage.replication.factor" = 1;
            "status.storage.topic" = "connect-status";
            "status.storage.replication.factor" = 1;
            "offset.flush.interval.ms" = "10000";
            "listeners" = "HTTP://:${builtins.toString cfg.kc-port}";
          };
        };
        karapace = {
          enable = cfg.schema-server;
          config = {
            bootstrap_uri = bootstrap-server;
            host = "0.0.0.0";
            port = cfg.karapace-port;
            karapace_registry = true;
            registry_user = false;
          };
        };
        akhq = {
          enable = cfg.ui-server;
          settings = {
            micronaut = {
              server = {
                port = cfg.ui-port;
                host = "0.0.0.0";
              };
            };
            akhq = {
              connections = {
                fmf = {
                  properties = { "bootstrap.servers" = bootstrap-server; };
                  schema-registry = {
                    url = "http://${cfg.karapace-lan-ip}:${
                        builtins.toString cfg.karapace-port
                      }";
                  };
                  connect = [{
                    name = "campground";
                    url = "http://${cfg.kc-lan-ip}:${
                        builtins.toString cfg.kc-port
                      }";
                  }];
                };
              };
            };
          };
        };
        postgresql = mkIf cfg.timescale-server {
          enable = true;
          extraPlugins = [ cfg.timescalePackage ];
          authentication = [ "local kafka kafka trust" ];
          databases = [{
            name = "kafka";
            user = "kafka";
          }];
          identMap = "kafka-map apache-kafka kafka";
        };
        zookeeper = {
          enable = true;
          id = cfg.zookeeper-id;
          # TODO: Figure out how to infer this
          servers = cfg.servers;
        };
        apache-kafka = {
          enable = true;
          settings = {
            "log.dirs" = [ "/var/lib/apache-kafka/logs" ];
            "listeners" =
              [ "PLAINTEXT://:${builtins.toString cfg.kafka-port}" ];
            "num.network.threads" = 3;
            "num.io.threads" = 8;
            "socket.send.buffer.bytes" = 102400;
            "socket.receive.buffer.bytes" = 102400;
            "socket.request.max.bytes" = 104857600;
            # TODO: Infer this
            "zookeeper.connect" =
              [ "chesty:2181" "webb:2181" "daly:2181" "lucas:2181" ];
            "num.partitions" = 3;
            "log.retention.hours" = 168;
            "message.max.bytes" = 1000012;
            "auto.create.topics.enable" = true;
          };
        };
      };
    };
  };
}
