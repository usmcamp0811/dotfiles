{ options, config, lib, ... }:
with lib;
with lib.campground;
let cfg = config.campground.services.prometheus;
in {
  options.campground.services.prometheus = with types; {
    enable = mkBoolOpt false "Enable an Prometheus";
    port = mkOpt int 9001 "Port to Host the Prometheus server on.";
    exporter-port = mkOpt int 9002 "Port to Host the Prometheus exporter on.";
    hostName = mkOpt str config.networking.hostName
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
          port = 9002;
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
