{ lib
, config
, ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.uptime-kuma;
in
{
  options.fmf.services.uptime-kuma = with types; {
    enable = mkBoolOpt false "Enable an Searx;";
    port = mkOpt int 4000 "Port to Host the uptime-kuma server on.";
  };

  config = mkIf cfg.enable {
    services.uptime-kuma = {
      enable = true;
      appriseSupport = true;
      settings = {
        PORT = "${toString cfg.port}";
        HOST = "0.0.0.0";
      };
    };

    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
