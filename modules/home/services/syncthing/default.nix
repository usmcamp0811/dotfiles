{
  options,
  config,
  lib,
  ...
}:
with lib;
with lib.fmf;
let
  cfg = config.fmf.services.syncthing;
in
{
  options.fmf.services.syncthing = with types; {
    enable = mkBoolOpt false "Whether or not to enable syncthing.";
  };

  config = mkIf cfg.enable {
    services.syncthing = {
      enable = true;
      tray = {
        enable = false;
      };
      extraOptions = [ "--no-default-folder" ];
    };
  };
}
