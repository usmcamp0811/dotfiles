{ options, config, lib, ... }:
with lib;
with lib.campground;
let cfg = config.campground.services.loki;
in {
  options.campground.services.loki = with types; {
    enable = mkBoolOpt false "Enable an Loki";
    exporter-enable = mkBoolOpt false "Enable an Loki Systemd Exporter";
    port = mkOpt int 9011 "Port to Host the Loki server on.";
    exporter-port = mkOpt int 9012 "Port to Host the Loki exporter on.";
    hostName = mkOpt str config.networking.hostName
      "The hostname or ip to use for Loki.";

  };

  config = mkIf (cfg.enable || cfg.exporter-enable) {
    services.loki = {
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
              toString config.services.loki.exporters.node.port
            }"
          ];
        }];
      }];
    };
  };
}
