{ options, config, lib, ... }:
with lib;
with lib.campground;

let cfg = config.campground.suites.observability;

in {
  options.campground.suites.observability = with types; {
    enable =
      mkBoolOpt false "Whether or not to enable observability reporters.";
    loki-uri = mkOpt str "webb:3030" "The <host>:<port> of the Loki server";
    prometheus = mkBoolOpt false "Whether or not to enable Prometheus server.";
    loki = mkBoolOpt false "Whether or not to enable Loki server.";
    grafana = mkBoolOpt false "Whether or not to enable Grafana server.";
    hostnames =
      mkOpt (listOf str) [ "mattis" "lucas" "chesty" "daly" "reckless" ]
      "List of hostnames for scrape configs.";
  };

  config = mkIf cfg.enable {
    campground = {
      services = {
        loki = { enable = cfg.loki; };
        prometheus = {
          enable = cfg.prometheus;
          exporter-enable = true;
          hostnames = cfg.hostnames;
        };
        promtail = {
          enable = true;
          loki-uri = cfg.loki-uri;
        };
      };
    };
  };
}
