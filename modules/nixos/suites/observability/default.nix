{
  options,
  config,
  lib,
  ...
}:
with lib;
with lib.campground;

let
  cfg = config.campground.suites.observability;

in
{
  options.campground.suites.observability = with types; {
    enable = mkBoolOpt false "Whether or not to enable observability reporters.";
    loki-uri = mkOpt str "webb:3030" "The <host>:<port> of the Loki server";
    prometheus = mkBoolOpt false "Whether or not to enable Prometheus server.";
    loki = mkBoolOpt false "Whether or not to enable Loki server.";
    grafana = mkBoolOpt false "Whether or not to enable Grafana server.";
    hostnames = mkOpt (listOf str) [
      "mattis"
      "lucas"
      "chesty"
      "daly"
      "reckless"
      "webb"
    ] "List of hostnames for scrape configs.";
  };

  config = mkIf cfg.enable {
    campground = {
      services = {
        loki = {
          enable = cfg.loki;
        };
        prometheus = {
          enable = cfg.prometheus;
          exporter-enable = true;
          hostnames = cfg.hostnames;
          additionalScrapeConfigs = [
            {
              job_name = "borgbackup-jobs";
              journal = {
                max_age = "12h";
                labels = {
                  job = "systemd-journal";
                  host = config.networking.hostName;
                };
              };
              relabel_configs = [
                # Match specific borgbackup services and count their successful deactivations
                {
                  source_labels = [ "__journal__systemd_unit" ];
                  regex = "borgbackup-job-webb_rsync.service|borgbackup-job-daly_rsync.service|borgbackup-job-campground.service";
                  action = "keep";
                }
                {
                  source_labels = [ "__journal_message" ];
                  regex = "Deactivated successfully";
                  action = "keep";
                }
                {
                  source_labels = [ "__journal__systemd_unit" ];
                  target_label = "borgbackup_service";
                  action = "replace";
                }
              ];
            }
          ];
        };
        promtail = {
          enable = true;
          loki-uri = cfg.loki-uri;

        };
      };
    };
  };
}
