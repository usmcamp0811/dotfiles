{ lib, config, pkgs, ... }:
with lib;
with lib.fmf;
let cfg = config.fmf.services.collabora;
in {
  options.fmf.services.collabora = with types; {
    enable = mkBoolOpt false "Enable collabora;";
    port = mkOpt int 19980 "Port to Host the Collabora server.";
  };
  config = mkIf cfg.enable {
    fmf.services.docker.enable = true;
    virtualisation.oci-containers.containers.collabora = {
      image = "docker.io/collabora/code";
      ports = [ "${toString cfg.port}:9980" ];
      autoStart = true;
      environment = {
        # This limits it to this NC instance AFAICT
        aliasgroup1 =
          "https://${config.fmf.services.nextcloud.domain}:443";
        # Must disable SSL as it's behind a reverse proxy
        extra_params = "--o:ssl.enable=false";
      };
    };

    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
