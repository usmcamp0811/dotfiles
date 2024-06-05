{ lib, config, ... }:
with lib;
let cfg = config.campground.services.prometheus;
in {
  options.campground.services.prometheus = {
    enable = mkEnableOption "Prometheus";
    port = mkOpt int 9001 "Port to Host the Prometheus server on.";
    exporter-port = mkOpt int 9002 "Port to Host the Prometheus exporter on.";
    host = mkOpt str config.networking.hostName
      "The hostname or ip to use for Prometheus.";
  };

  config = mkIf cfg.enable {
    services.prometheus = {
      enable = true;
      port = cfg.port;
      exporters = {
        node = {
          enable = true;
          enabledCollectors = [ "systemd" ];
          port = cfg.exporter-port;
        };
      };
      scrapeConfigs = [{
        job_name = "${cfg.host}-system-monitor";
        static_configs = [{
          targets = [
            "${cfg.host}:${
              toString config.services.prometheus.exporters.node.port
            }"
          ];
        }];
      }];
    };
  };
}
