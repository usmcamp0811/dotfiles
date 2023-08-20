{ options, config, pkgs, lib, ... }:

with lib;
let
  cfg = config.campground.hardware.intel;
in
{
  options.campground.hardware.intel = with types; {
    enable = mkEnableOption "Intel Graphics";
  };

  config = mkIf cfg.enable {
    boot.kernelPackages = pkgs.linuxPackages_zen;
    environment.systemPackages = [
      pkgs.linuxKernel.packages.linux_zen.nvidia_x11
    ];

    services.xserver.config = ''
      # Integrated Intel GPU
      Section "Device"
        Identifier "iGPU"
        Driver "modesetting"
      EndSection

      # Dedicated NVIDIA GPU
      Section "Device"
        Identifier "dGPU"
        Driver "nvidia"
      EndSection

      Section "ServerLayout"
        Identifier "layout"
        Screen 0 "iGPU"
      EndSection

      Section "Screen"
        Identifier "iGPU"
        Device "iGPU"
      EndSection
    '';

    services.xserver.videoDrivers = [ "nvidia" ];
    hardware.nvidia.prime = {
      offload.enable = true;
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };
}
