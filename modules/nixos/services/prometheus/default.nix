{ options, config, lib, ... }:
with lib;
with lib.campground;
let cfg = config.campground.services.prometheus;
in {
  options.campground.services.prometheus = with types; {
    enable = mkBoolOpt false "Enable an Prometheus";
    exporter-enable = mkBoolOpt false "Enable an Prometheus Systemd Exporter";
    port = mkOpt int 9011 "Port to Host the Prometheus server on.";
    exporter-port = mkOpt int 9012 "Port to Host the Prometheus exporter on.";
    hostName = mkOpt str config.networking.hostName
      "The hostname or ip to use for Prometheus.";

  };

  config = mkIf (cfg.enable || cfg.exporter-enable) {
    services.prometheus = {
      enable = cfg.enable;
      port = cfg.port;
      exporters = {
        node = {
          enable = cfg.exporter-enable;
          enabledCollectors = [ "systemd" ];
          port = cfg.exporter-port;
        };
      };
      scrapeConfigs = [{
        job_name = "${cfg.hostName}-system-monitor";
        static_configs = [{
          targets = [
            "${cfg.hostName}:${
              toString config.services.prometheus.exporters.node.port
            }"
          ];
        }];
      }];
    };
  };
}
