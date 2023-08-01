{ options, config, pkgs, lib, ... }:

with lib;
with lib.internal;
let cfg = config.campground.hardware.nvidia;
in
{
  options.campground.hardware.nvidia = with types; {
    enable = mkBoolOpt false "Whether or not to enable Nvidia support";
  };

  services.xserver.videoDrivers = [ "nvidia" ];
  config = mkIf cfg.enable {
    hardware.nvidia.prime = {
      sync.enable = true;
      nvidiaBusId = "PCI:1:0:0";
      intelBusId = "PCI:0:2:0";
    };
  };
}
