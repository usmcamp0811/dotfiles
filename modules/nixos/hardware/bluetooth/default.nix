{ options, config, pkgs, lib, ... }:

with lib;
with lib.campground;
let cfg = config.campground.hardware.bluetooth;
in {
  options.campground.hardware.bluetooth = with types; {
    enable = mkBoolOpt false "Whether or not to enable bluetooth support";
  };

  config = mkIf cfg.enable {
    services.blueman.enable = true;
    hardware.bluetooth.enable = true;
    hardware.bluetooth.powerOnBoot = true;

    environment.systemPackages = with pkgs; [ blueman ];
  };
}
