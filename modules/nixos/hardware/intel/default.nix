{ options, config, pkgs, lib, ... }:

with lib;
let cfg = config.campground.hardware.intel;
in {
  options.campground.hardware.intel = with types; {
    enable = mkEnableOption "Intel Graphics";
  };

  config = mkIf cfg.enable {
    # services.xserver.videoDrivers = [ "intel" ];
  };
}
