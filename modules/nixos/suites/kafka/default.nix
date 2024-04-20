{ host ? "", options, config, lib, pkgs, ... }:
with lib;
with lib.campground;
let 
  cfg = config.campground.suites.kafka;
  bootstrap-server = "${cfg.kafka-lan-ip}:${cfg.kakfa-port}"
in {
  options.campground.suites.kafka = with types; {
    enable = mkBoolOpt false "Whether or not to enable kafka configuration.";
    interface = mkOpt str "eno1"
      "Interface to use for the LAN Instance when setting up Keepalived for Kafka";
    kafka-interface = mkOpt str cfg.interface
      "Interface to use for the LAN Instance when setting up Keepalived for Kafka";
    kafka-port = mkOpt int 9092 "Port to Host the Apache Kafka server.";
    kafka-lan-ip = mkOpt str "10.8.0.72"
      "IP to use for the LAN Instance when setting up Keepalived for Kafka";
    zookeeper-id = mkOpt int 0 "Zookeeper Server ID";
    timescalePackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.postgresql16Packages.timescaledb;
      description = "TimescaleDB package to use.";
    };
    timescale-server = mkBoolOpt false
      "Wheather or not to enable Postgres with Timescale on this server.";
    ui-server =
      mkBoolOpt false "Wheather or not to enable AKHQ on this server.";
    schema-server =
      mkBoolOpt false "Wheather or not to enable Karapace on this server.";
    ui-port = mkOpt int 8435 "Port to Host the Apache Kafka HQ server.";
    ui-bootstrap-server = mkOpt str "webb:9092" "Kafka server address";
    kc-interface = mkOpt str cfg.interface
      "Interface to use for the LAN Instance when setting up Keepalived for Kafka Connect";
    kc-lan-ip = mkOpt str "10.8.0.70"
      "IP to use for the LAN Instance when setting up Keepalived for Kafka Connect";
    kc-port = mkOpt int 8323 "Port to Host the Kafka Connect server.";
    karapace-interface = mkOpt str cfg.interface
      "Interface to use for the LAN Instance when setting up Keepalived for Karapace";
    karapace-lan-ip = mkOpt str "10.8.0.71"
      "IP to use for the LAN Instance when setting up Keepalived for Karapace";
    karapace-port = mkOpt int 8436 "Port to Host the Apache Kafka HQ server.";
    connect-server =
      mkBoolOpt false "Wheather or not to enable Kafka Connect on this server.";
    servers = mkOption {
      description = lib.mdDoc "All Zookeeper Servers.";
      type = types.lines;
      default = ''
        server.1=chesty:2888:3888
        server.2=webb:2888:3888
        server.3=daly:2888:3888
        server.4=lucas:2888:3888
      '';
    };
  };

  config = mkIf cfg.enable {

    networking.firewall = { allowedTCPPorts = [ 2181 2888 3888 9092 ]; };

    campground = {
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
              virtualRouterId = 54;
            };
            "karapace" = mkIf cfg.schema-server {
              interface = cfg.karapace-interface;
              ips = [ cfg.karapace-lan-ip ];
              state = "MASTER";
              priority = 50;
              virtualRouterId = 55;
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
            "listeners" = "HTTP://:8323";
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
                campground = {
                  properties = {
                    "bootstrap.servers" = bootstrap-server;
                  };
                  schema-registry = {
                    url = "http://${cfg.karapace-lan-ip}:${
                        builtins.toString cfg.karapace-port
                      }";
                  };
                  connect = {
                    url = "http://${cfg.kc-lan-ip}:${
                        builtins.toString cfg.kc-port
                      }";
                  };
                };
              };
            };
          };
        };
        postgresql = {
          enable = cfg.timescale-server;
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
            "listeners" = [ "PLAINTEXT://:${cfg.kafka-port}" ];
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
