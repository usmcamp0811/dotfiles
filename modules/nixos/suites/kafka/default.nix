{ options, config, lib, ... }:
with lib;
with lib.campground;
let cfg = config.campground.suites.kafka;
in {
  options.campground.suites.kafka = with types; {
    enable = mkBoolOpt false "Whether or not to enable kafka configuration.";
  };

  config = mkIf cfg.enable {
    campground = {
      services = {
        zookeeper = {
          enable = true;
          # TODO: Figure out how to infer this
          servers = ''
            server.0=lucas:2888:3888
            server.1=chesty:2888:3888
            server.2=webb:2888:3888
            server.3=daly:2888:3888
          '';
        };
        apache-kafka = {
          enable = true;
          settings = {
            "broker.id" = 1;
            "log.dirs" = [ "/var/lib/kafka/logs" ];
            "listeners" = [ "PLAINTEXT://:9092" ];
            "num.network.threads" = 3;
            "num.io.threads" = 8;
            "socket.send.buffer.bytes" = 102400;
            "socket.receive.buffer.bytes" = 102400;
            "socket.request.max.bytes" = 104857600;
            "zookeeper.connect" = "localhost:2181";
            "num.partitions" = 3;
            "log.retention.hours" = 168;
            "message.max.bytes" = 1000012;
            "auto.create.topics.enable" = false;
          };
        };
      };
    };
  };
}
