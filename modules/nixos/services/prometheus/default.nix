{
  options,
  config,
  pkgs,
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
      # Existing node exporter scrape config
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
      # New script exporter scrape config
      {
        job_name = "${hostname}-script-exporter";
        static_configs = [ { targets = [ "${hostname}:${toString cfg.scriptExporterPort}" ]; } ];
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
  test-script = pkgs.writeShellScriptBin "test-script" ''
    sleep 3
  '';
  test-script2 = pkgs.writeShellScriptBin "test-script2" ''
    echo "# HELP test_second_test"
    echo "# TYPE test_second_test gauge"
    echo "second_test{label2=\"test_2_label_1\"} 1"
  '';

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
    scriptFiles = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Script files for the Prometheus Script Exporter.";
    };
    scriptExporterPort = mkOpt int 9105 "Port for the script exporter.";
  };

  config = mkIf (cfg.enable || cfg.exporter-enable) {
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
                name = "campground_test_script";
                script = "${test-script}/bin/test-script";
              }
              {
                name = "test_script_2";
                script = "${test-script2}/bin/test-script2";
              }
            ];
            # scripts = lib.mapAttrsToList (name: scriptAttrs: {
            #   name = name;
            #   script = scriptAttrs;
            #   timeout = scriptAttrs.timeout or 5;
            # }) cfg.scriptFiles;
          };
        };
        node = {
          enable = cfg.exporter-enable;
          enabledCollectors = [ "systemd" ]; # ++ cfg.additionalCollectors;
          port = cfg.exporter-port;
        };
      };
      scrapeConfigs = generateScrapeConfigs cfg.hostnames ++ cfg.additionalScrapeConfigs;
    };
  };
}
