{ options, config, lib, ... }:
with lib;
with lib.campground;
let cfg = config.campground.services.promtail;
in {
  options.campground.services.promtail = with types; {
    enable = mkBoolOpt false "Enable an Promtail";
    port = mkOpt int 3031 "Port to Host the Promtail server on.";
    loki-host = mkOpt str config.networking.hostName
      "The hostname or ip to use for Promtail to scrape.";

  };

  config = mkIf cfg.enable {
    services.promtail = {
      enable = true;
      configuration = {
        server = {
          http_listen_port = cfg.port;
          grpc_listen_port = 0;
        };
        positions = { filename = "/tmp/positions.yaml"; };
        clients = [{
          url = "http://${cfg.loki-host}:${
              toString cfg.loki-port
            }/loki/api/v1/push";
        }];
        scrape_configs = [{
          job_name = "journal";
          journal = {
            max_age = "12h";
            labels = {
              job = "systemd-journal";
              host = cfg.hostName;
            };
          };
          relabel_configs = [{
            source_labels = [ "__journal__systemd_unit" ];
            target_label = "unit";
          }];
        }];
      };
      # extraFlags
    };
  };
}
