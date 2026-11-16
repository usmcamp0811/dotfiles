{
  options,
  config,
  pkgs,
  lib,
  ...
}:
with lib;
with lib.fmf;

let
  cfg = config.fmf.suites.observability;

in
{
  options.fmf.suites.observability = with types; {
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
    fmf = {
      services = {
        loki = {
          enable = cfg.loki;
        };
        prometheus = {
          enable = cfg.prometheus;
          exporter-enable = true;
          hostnames = cfg.hostnames;
          scriptFiles = {
            # Using pkgs.writeShellScriptBin
            anotherScript = ''
              echo "another_metric 2"
            '';
          };
          additionalScrapeConfigs = [
            # {
            #   job_name = "borgbackup-job-${config.networking.hostName}_rsync";
            #   static_configs = [
            #     {
            #       targets = [ "${config.networking.hostName}:9012" ]; # Assuming the node exporter runs on port 9012
            #     }
            #   ];
            #   metrics_path = "/metrics";
            #   relabel_configs = [
            #     {
            #       source_labels = [ "__meta_systemd_service" ];
            #       regex = "borgbackup-job-${config.networking.hostName}_rsync";
            #       action = "keep";
            #     }
            #   ];
            # }
          ];
        };
        # NOTE: no log shipper is enabled here. NixOS removed services.promtail (Promtail EOL), so the
        # fmf.services.promtail shim did nothing but warn. `loki-uri` is kept for the Alloy/fluent-bit
        # replacement; the old borgbackup journal scrape (job borgbackup-jobs, units
        # borgbackup-job-{webb_rsync,daly_rsync,fmf}, "Deactivated successfully") is in git history.
      };
    };
  };
}
