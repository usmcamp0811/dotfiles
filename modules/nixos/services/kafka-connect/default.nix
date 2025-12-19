{ host ? "", options, config, lib, pkgs, ... }:

with lib;
with lib.fmf;
let 
  cfg = config.fmf.services.kafka-connect;
  kafka-connect-config = builtins.concatStringsSep "\n" (
    lib.mapAttrsToList (name: value: "${name}=${builtins.toString value}") cfg.config
  );
in {
  options.fmf.services.kafka-connect = with types; {
    enable = mkBoolOpt false "Whether or not to enable Kafka Connect.";
    config = mkOption {
      type = types.attrs;
      default = {
        "bootstrap.servers" = "localhost:9092";
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
      description = "Kafka Connect configuration.";
    };
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
        # Write the Kafka Connect configuration file
        echo '${kafka-connect-config}' > /var/lib/apache-kafka/kafka-connect.cfg
        export KAFKA_HEAP_OPTS="-Xmx1G -Xms1G"
        export KAFKA_LOG_DIR="/var/log/apache-kafka"
        ${pkgs.apacheKafka}/bin/connect-distributed.sh /var/lib/apache-kafka/kafka-connect.cfg
      '';
      serviceConfig = {
        Restart = "always";
        User = "apache-kafka";
      };
    };
  };
}
