{ options, config, lib, ... }:
with lib;
with lib.fmf;
let cfg = config.fmf.services.promtail;
in {
  options.fmf.services.promtail = with types; {
    enable = mkBoolOpt false "Enable an Promtail";
    port = mkOpt int 3031 "Port to listen on";
    loki-uri = mkOpt str "localhost:3030" "loki host:port";
    hostName = mkOpt str config.networking.hostName
      "The hostname or ip to use for Promtail to scrape.";
    additionalScrapeConfigs = mkOpt (listOf (attrsOf anything)) [ ]
      "Additional scrape configs for Loki/Promtail.";

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
        clients = [{ url = "http://${cfg.loki-uri}/loki/api/v1/push"; }];
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
        }] ++ cfg.additionalScrapeConfigs;
      };
    };
  };
}
