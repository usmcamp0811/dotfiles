{ options, config, lib, ... }:
with lib;
with lib.campground;

let
  cfg = config.campground.services.prometheus;
  generateScrapeConfigs = hostnames:
    lib.concatMap (hostname: [
      # Existing node exporter scrape config
      {
        job_name = "${hostname}-system-monitor";
        static_configs =
          [{ targets = [ "${hostname}:${toString cfg.exporter-port}" ]; }];
        relabel_configs = [{
          source_labels = [ "__address__" ];
          regex = "([^:]+):.*";
          target_label = "instance";
          replacement = "$1";
        }];
      }
      # New script exporter scrape config
      {
        job_name = "${hostname}-script-exporter";
        static_configs =
          [{ targets = [ "${hostname}:${toString cfg.scriptExporterPort}" ]; }];
        relabel_configs = [{
          source_labels = [ "__address__" ];
          regex = "([^:]+):.*";
          target_label = "instance";
          replacement = "$1";
        }];
      }
    ]) hostnames;

in {
  options.campground.services.prometheus = with types; {
    enable = mkBoolOpt false "Enable Prometheus";
    exporter-enable = mkBoolOpt false "Enable Prometheus Systemd Exporter";
    port = mkOpt int 9011 "Port to Host the Prometheus server on.";
    exporter-port = mkOpt int 9012 "Port to Host the Prometheus exporter on.";
    exporter-host = mkOpt str "webb" "The hostname or IP running Prometheus.";
    hostName = mkOpt str config.networking.hostName
      "The hostname or IP to use for Prometheus.";
    additionalScrapeConfigs = mkOpt (listOf (attrsOf anything)) [ ]
      "Additional scrape configs for Prometheus.";
    hostnames = mkOpt (listOf str) [ ] "List of hostnames for scrape configs.";
    additionalCollectors =
      mkOpt (listOf str) [ ] "List of additional Collectors";
    scriptFiles = mkOption {
      type = types.attrsOf types.package;
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
            scripts = lib.mapAttrsToList (name: scriptAttrs:
              let
                scriptDerivation = scriptAttrs;
                scriptPath =
                  if builtins.pathExists "${scriptDerivation}/bin/${name}" then
                    "${scriptDerivation}/bin/${name}"
                  else if builtins.pathExists "${scriptDerivation}/${name}" then
                    "${scriptDerivation}/${name}"
                  else
                    (throw
                      "Cannot find script file for '${name}' in derivation '${scriptDerivation}'");
              in {
                name = name;
                script = scriptPath;
                timeout = scriptAttrs.timeout or 5;
              }) cfg.scriptFiles;
          };
        };
        node = {
          enable = cfg.exporter-enable;
          enabledCollectors = [ "systemd" ]; # ++ cfg.additionalCollectors;
          port = cfg.exporter-port;
        };
      };
      scrapeConfigs = generateScrapeConfigs cfg.hostnames
        ++ cfg.additionalScrapeConfigs;
    };
  };
}
