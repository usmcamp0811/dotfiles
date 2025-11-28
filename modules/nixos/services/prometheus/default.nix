{
  options,
  config,
  pkgs,
  lib,
  ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.services.prometheus;
  generateScrapeConfigs = hostnames:
    lib.concatMap (hostname: [
      # Existing node exporter scrape config
      {
        job_name = "${hostname}-system-monitor";
        static_configs = [{targets = ["${hostname}:${toString cfg.exporter-port}"];}];
        relabel_configs = [
          {
            source_labels = ["__address__"];
            regex = "([^:]+):.*";
            target_label = "instance";
            replacement = "$1";
          }
        ];
      }
      # New script exporter scrape config
      {
        job_name = "${hostname}-script-exporter";
        static_configs = [{targets = ["${hostname}:${toString cfg.scriptExporterPort}"];}];
        metrics_path = "/probe";
        params = {
          pattern = [".*"]; # Pass pattern as a query parameter
        };
        relabel_configs = [
          {
            source_labels = ["__address__"];
            regex = "([^:]+):.*";
            target_label = "instance";
            replacement = "$1";
          }
        ];
      }
      {
        job_name = "${hostname}-systemd-exporter";
        static_configs = [
          {
            targets = ["${hostname}:${toString cfg.systemdExporterPort}"];
          }
        ];
        metrics_path = "/metrics";
        relabel_configs = [
          {
            source_labels = ["__address__"];
            regex = "([^:]+):.*";
            target_label = "instance";
            replacement = "$1";
          }
        ];
      }
    ])
    hostnames;
  test-script = pkgs.writeShellScriptBin "test-script" ''
    echo "STARTING TEST"
    echo "test{name=\"shit\"} 42"
    echo "END TEST"
  '';
in {
  options.campground.services.prometheus = with types; {
    enable = mkBoolOpt false "Enable Prometheus";
    exporter-enable = mkBoolOpt false "Enable Prometheus Systemd Exporter";
    port = mkOpt int 9011 "Port to Host the Prometheus server on.";
    exporter-port = mkOpt int 9012 "Port to Host the Prometheus exporter on.";
    exporter-host = mkOpt str "webb" "The hostname or IP running Prometheus.";
    hostName =
      mkOpt str config.networking.hostName
      "The hostname or IP to use for Prometheus.";
    additionalScrapeConfigs =
      mkOpt (listOf (attrsOf anything)) []
      "Additional scrape configs for Prometheus.";
    hostnames = mkOpt (listOf str) [] "List of hostnames for scrape configs.";
    additionalCollectors =
      mkOpt (listOf str) [] "List of additional Collectors";
    scriptFiles = mkOption {
      type = types.attrsOf types.str;
      default = {};
      description = "Script files for the Prometheus Script Exporter.";
    };
    scriptExporterPort = mkOpt int 9105 "Port for the script exporter.";
    systemdExporterPort = mkOpt int 9558 "Port for the systemd exporter.";
    fileExporterDir =
      mkOpt str "/var/lib/node_exporter" "Place to the file exporter will look";
  };

  config = mkIf (cfg.enable || cfg.exporter-enable) {
    # Ensure the directory has the correct owner and permissions
    users.groups.prometheus.gid = config.ids.gids.prometheus;
    users.users.prometheus = {
      description = "Prometheus daemon user";
      uid = config.ids.uids.prometheus;
      group = "prometheus";
    };
    systemd.tmpfiles.rules = ["d ${cfg.fileExporterDir} 0755 prometheus prometheus -"];
    services.prometheus = {
      enable = cfg.enable;
      port = cfg.port;
      exporters = {
        systemd.enable = true;
        script = {
          enable = true;
          port = cfg.scriptExporterPort;
          openFirewall = true;

          # Define scripts under settings.scripts
          settings = {
            scripts = [
              {
                name = "shit-script";
                command = ["${test-script}/bin/test-script"];
              }
            ];
          };
        };
        node = {
          enable = cfg.exporter-enable;
          enabledCollectors = ["textfile" "systemd"];
          port = cfg.exporter-port;
          extraFlags = ["--collector.textfile.directory=${cfg.fileExporterDir}"];
        };
      };
      scrapeConfigs =
        generateScrapeConfigs cfg.hostnames
        ++ cfg.additionalScrapeConfigs;
    };
  };
}
