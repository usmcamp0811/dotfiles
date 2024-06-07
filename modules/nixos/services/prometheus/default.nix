{ options, config, lib, ... }:
with lib;
with lib.campground;
let cfg = config.campground.services.prometheus;
in {
  options.campground.services.prometheus = with types; {
    enable = mkBoolOpt false "Enable Prometheus";
    exporter-enable = mkBoolOpt false "Enable Prometheus Systemd Exporter";
    port = mkOpt int 9011 "Port to Host the Prometheus server on.";
    exporter-port = mkOpt int 9012 "Port to Host the Prometheus exporter on.";
    exporter-host = mkOpt str config.networking.hostName 
      "The hostname or IP to use for Prometheus.";
    hostName = mkOpt str config.networking.hostName
      "The hostname or IP to use for Prometheus.";
    additionalStaticConfigTargets =
      mkOpt (listOf str) [ ] "Additional static config targets for Prometheus.";
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
            "${cfg.exporter-host}:${ toString config.services.prometheus.exporters.node.port }"
          ] ++ cfg.additionalStaticConfigTargets;
        }];
      }];
    };
  };
}
