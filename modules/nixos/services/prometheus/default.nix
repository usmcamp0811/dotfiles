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
        metrics_path = "/probe";
        params = {
          pattern = [ ".*" ]; # Pass pattern as a query parameter
        };
        relabel_configs = [
          {
            source_labels = [ "__address__" ];
            regex = "([^:]+):.*";
            target_label = "instance";
            replacement = "$1";
          }
        ];
      }
      {
        job_name = "${hostname}-systemd-exporter";
        static_configs = [ { targets = [ "${hostname}:${toString cfg.systemdExporterPort}" ]; } ];
        metrics_path = "/metrics";
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
    echo "shit" >> /tmp/shitfile
    echo "test{name=\"shit\"} 69"
  '';
  borg-backup-probe-time = pkgs.writeShellScriptBin "borg-backup-probe" ''
    echo "borg_last_run_timestamp{name=\"webb\"} $(/run/current-system/sw/bin/systemctl show -p ExecMainExitTimestampMonotonic --value borgbackup-job-webb_rsync)"
  '';

  borg-backup-probe-status = pkgs.writeShellScriptBin "borg-backup-probe" ''
    borg_last_exit=$(/run/current-system/sw/bin/systemctl show -p ExecMainStatus --value borgbackup-job-webb_rsync)
    echo "borg_last_exit{name=\"webb\"} $borg_last_exit" > /var/lib/node_exporter/textfile_collector/borg-backup-probe-status.prom
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
    systemdExporterPort = mkOpt int 9558 "Port for the systemd exporter.";
  };

  config = mkIf (cfg.enable || cfg.exporter-enable) {
    # Allow 'script-exporter' group to run specific systemctl commands without password
    security.sudo.extraRules = [
      {
        groups = [ "script-exporter" ];
        commands = [
          {
            command = "/run/current-system/sw/bin/systemctl show -p ExecMainStatus --value borgbackup-job-webb_rsync";
            options = [ "NOPASSWD" ];
          }
          {
            command = "/run/current-system/sw/bin/systemctl show -p ExecMainExitTimestampMonotonic --value borgbackup-job-webb_rsync";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];
    # Create the textfile collector directory
    environment.etc."node_exporter/textfile_collector" = {
      source = null; # Creates an empty directory
      mode = "0755"; # Permissions: readable and writable
    };

    # Ensure the directory has the correct owner and permissions
    systemd.tmpfiles.rules = [
      "d /var/lib/node_exporter 0755 prometheus prometheus -"
      "d /var/lib/node_exporter/textfile_collector 0755 prometheus prometheus -"
    ];
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
                script = "${test-script}/bin/test-script";
              }
              {
                name = "borg-backup-probe-time";
                script = "${borg-backup-probe-time}/bin/borg-backup-probe";
              }
              {
                name = "borg-backup-probe-status";
                script = "${borg-backup-probe-status}/bin/borg-backup-probe";
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
          extraArgs = [ "--collector.textfile.directory=/var/lib/node_exporter/textfile_collector" ];
        };
      };
      scrapeConfigs = generateScrapeConfigs cfg.hostnames ++ cfg.additionalScrapeConfigs;
    };
  };
}
