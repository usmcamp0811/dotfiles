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
    warnings = [
      "fmf.services.promtail is enabled, but NixOS removed services.promtail (Promtail EOL). Please migrate to services.alloy or services.fluent-bit."
    ];
  };
}
