{ options, config, lib, ... }:
with lib;
with lib.campground;
let cfg = config.campground.suites.kafka;
in {
  options.campground.suites.kafka = with types; {
    enable = mkBoolOpt false "Whether or not to enable kafka configuration.";
    zookeeper-id = mkOpt int 0 "Zookeeper Server ID";
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

    networking.firewall = {
      allowedTCPPorts = [ 2181 2888 3888 9092 ]; 
    };
    campground = {
      services = {
        postgresql.extraPlugins = [ pkgs.postgresql16Packages.timescaledb ];
        zookeeper = {
          enable = true;
          id = cfg.zookeeper-id;
          # TODO: Figure out how to infer this
          servers = cfg.servers;
        };
        apache-kafka = {
          enable = true;
          settings = {
            "log.dirs" = [ "/var/lib/kafka/logs" ];
            "listeners" = [ "PLAINTEXT://:9092" ];
            "num.network.threads" = 3;
            "num.io.threads" = 8;
            "socket.send.buffer.bytes" = 102400;
            "socket.receive.buffer.bytes" = 102400;
            "socket.request.max.bytes" = 104857600;
            "zookeeper.connect" = ["chesty:2181" "webb:2181" "daly:2181" "lucas:2181"];
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
