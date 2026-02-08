{ lib, config, pkgs, ... }:
with lib;
with lib.fmf;
let cfg = config.fmf.kafka-producers.traefik-logs;
in {
  options.fmf.kafka-producers.traefik-logs = with types; {
    enable = mkBoolOpt false "Enable Kafka Producer for Traefik Logs;";
    kafkaBroker = mkOpt str "${config.fmf.suites.kafka.kafka-lan-ip}:${
        builtins.toString config.fmf.suites.kafka.kafka-port
      }" "Kafka broker address.";
    kafkaTopic = mkOpt str "traefik-logs" "Kafka topic to which logs are sent.";
  };

  config = mkIf cfg.enable {
    systemd.services.kafka-producer-traefik-logs = {
      description = "Traefik Log Watcher Service";
      wantedBy = [ "multi-user.target" ];
      after = [ "traefik.service" ];
      serviceConfig = {
        User = "traefik";
        Restart = "on-failure";
        WorkingDirectory = "/var/lib/traefik";
      };
      environment = {
        KT_BROKERS = cfg.kafkaBroker;
        KT_TOPIC = cfg.kafkaTopic;
        TRAEFIK_LOG = config.fmf.services.traefik.log-path;
      };
      script = ''
        while true; do
          ${pkgs.inotify-tools}/bin/inotifywait -m $TRAEFIK_LOG -e access -e modify -e open --format '%w%f' | while read path; do
            (tail -n 1 $TRAEFIK_LOG | ${pkgs.kt}/bin/kt produce -literal) && (sed -i '$d' $TRAEFIK_LOG >/dev/null)
          done
        done
      '';
    };
  };
}
