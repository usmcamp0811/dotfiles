{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.services.syncthing;
in {
  options.campground.services.syncthing = with types; {
    enable = mkBoolOpt false "Whether or not to enable syncthing.";
  };

  config = mkIf cfg.enable {
    services.syncthing = {
      enable = true;
      tray = {enable = false;};
      extraOptions = ["--no-default-folder"];
    };
  };
}
