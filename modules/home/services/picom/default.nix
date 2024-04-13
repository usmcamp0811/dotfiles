{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.services.picom;
in {
  options.campground.services.picom = with types; {
    enable = mkBoolOpt false "Whether or not to enable picom.";
  };

  config = mkIf cfg.enable {
    # programs.picom.enable = true;
  };
}
