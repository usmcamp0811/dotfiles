{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.services.collabora;
in {
  options.campground.services.collabora = with types; {
    enable = mkBoolOpt false "Enable collabora;";
  };

  config =
    mkIf cfg.enable {
    virtualisation.oci-containers.containers.collabora = {
      image = "docker.io/collabora/code";
      ports = [ "9980:9980" ];
      autoStart = true;
      environment = {
        # This limits it to this NC instance AFAICT
        aliasgroup1 = "https://${campground.services.nextcloud.domain}:443";
        # Must disable SSL as it's behind a reverse proxy
        extra_params = "--o:ssl.enable=false";
      };
    };
  };
}
