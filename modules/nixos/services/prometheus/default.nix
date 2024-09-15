{
  options,
  config,
  lib,
  ...
}:
with lib;
with lib.campground;

let
  cfg = config.campground.services.prometheus;

  generateScrapeConfigs =
    hostnames:
    lib.concatMap (hostname: [
      {
        job_name = "${hostname}-system-monitor";
        static_configs = [ { targets = [ "${hostname}:${toString cfg.exporter-port}" ]; } ];
        relabel_configs = [
          {
            source_labels = [ "__address__" ];
            regex = "([^:]+):.*";
            target_label = "instance";
            replacement = "$1";
          }
        ];
      }
    ]) hostnames;

in
{
  options.campground.services.prometheus = with types; {
    enable = mkBoolOpt false "Enable Prometheus";
    exporter-enable = mkBoolOpt false "Enable Prometheus Systemd Exporter";
    port = mkOpt int 9011 "Port to Host the Prometheus server on.";
    exporter-port = mkOpt int 9012 "Port to Host the Prometheus exporter on.";
    exporter-host = mkOpt str "webb" "The hostname or IP running Prometheus.";
    hostName = mkOpt str config.networking.hostName "The hostname or IP to use for Prometheus.";
    additionalScrapeConfigs = mkOpt (listOf (
      attrsOf anything
    )) [ ] "Additional scrape configs for Prometheus.";
    hostnames = mkOpt (listOf str) [ ] "List of hostnames for scrape configs.";
    additionalCollectors = mkOpt (listOf str) [ ] "List of additional Collectors";
  };

  config = mkIf (cfg.enable || cfg.exporter-enable) {
    services.prometheus = {
      enable = cfg.enable;
      port = cfg.port;
      exporters = {
        systemd = enable;
        node = {
          enable = cfg.exporter-enable;
          enabledCollectors = [ "systemd" ] ++ additionalCollectors;
          port = cfg.exporter-port;
        };
      };
      scrapeConfigs = generateScrapeConfigs cfg.hostnames ++ cfg.additionalScrapeConfigs;
    };
  };
}
