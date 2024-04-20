{ host ? "", options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let 
  cfg = config.campground.services.kafka-connect;
in {
  options.campground.services.kafka-connect = with types; {
    enable = mkBoolOpt false "Whether or not to enable Kafka Connect.";
  };

  config = mkIf cfg.enable {
    users.users.apache-kafka = {
      isSystemUser = true;
      group = "apache-kafka";
      home = "/var/lib/apache-kafka";
      createHome = true;
    };

    users.groups.apache-kafka = {};

    systemd.services.kafka-connect = {
      description = "Kafka Connect";
      after = [ "network.target" "apache-kafka.service" ];
      requires = [ "apache-kafka.service" ];
      wantedBy = [ "multi-user.target" ];
      script = ''
        export KAFKA_HEAP_OPTS="-Xmx1G -Xms1G"
        export KAFKA_LOG_DIR="/var/log/apache-kafka"
        ${pkgs.apacheKafka}/bin/connect-distributed.sh ${pkgs.apacheKafka}/config/connect-distributed.properties
      '';
      serviceConfig = {
        Restart = "always";
        User = "apache-kafka";
      };
    };
  };
}
