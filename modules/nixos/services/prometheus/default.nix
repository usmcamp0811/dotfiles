{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.services.prometheus;
in {
  options.campground.services.prometheus = {
    enable = mkEnableOption "Prometheus";
  };

  config = mkIf cfg.enable {
    services.prometheus = {
      enable = true;
      scrapeConfigs = [{
        job_name = "systemd";
        static_configs = [{
          targets = [ "localhost:9100" ]; # Add all your machine addresses here
        }];
      }];
    };

    services.grafana = {
      enable = true;
      datasources = [{
        name = "Prometheus";
        type = "prometheus";
        url = "http://localhost:9090"; # Address of your Prometheus server
        access = "proxy";
      }];
      dashboards.default = {
        systemd = {
          title = "Systemd Services";
          panels = [{
            title = "Service Status";
            type = "table";
            targets = [{ expr = "up{job='systemd'}"; }];
          }];
        };
      };
    };

    services.node_exporter = {
      enable = true;
      textfileCollector = {
        enable = true;
        files = "/var/lib/node_exporter/*.prom";
      };
    };
  };
}
