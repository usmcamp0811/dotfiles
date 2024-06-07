{ options, config, lib, ... }:
with lib;
with lib.campground;
let cfg = config.campground.suites.observability;
in {
  options.campground.suites.observability = with types; {
    enable =
      mkBoolOpt false "Whether or not to enable observability reporters.";
    loki-uri = mkOpt str "webb:3030" "The <host>:<port> of the Loki server";
  };

  config = mkIf cfg.enable {
    campground = {
      services = {
        prometheus = {
          exporter-enable = true;
          additionalScrapeConfigs = [{
            job_name = "traefik-monitor";
            static_configs =
              [{ targets = [ "10.8.0.42:58082" "10.8.0.69:58082" ]; }];
          }];

        };
        promtail = {
          enable = true;
          loki-uri = cfg.loki-uri;
        };
      };
    };
  };
}
