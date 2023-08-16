{ options, config, pkgs, lib, ... }:

with lib;
with lib.internal;
let cfg = config.campground.hardware.bluetooth;
in
{
  options.campground.hardware.bluetooth = with types; {
    enable = mkBoolOpt false "Whether or not to enable bluetooth support";
  };

  config = mkIf cfg.enable {
    # services.bluetooth.enable = true;

    #environment.systemPackages = with pkgs; [
      #blueman
    #];
  };
}
