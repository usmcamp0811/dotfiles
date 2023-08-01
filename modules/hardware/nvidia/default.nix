{ options, config, pkgs, lib, ... }:

with lib;
with lib.internal;
let cfg = config.campground.hardware.nvidia;
in
{
  options.campground.hardware.nvidia = with types; {
    enable = mkBoolOpt false "Whether or not to enable Nvidia support";
  };

  config = mkIf cfg.enable {
    hardware.opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
    };

    # Tell Xorg to use the nvidia driver (also valid for Wayland)
    services.xserver.videoDrivers = ["nvidia"];

    hardware.nvidia = {

      # Modesetting is needed for most Wayland compositors
      modesetting.enable = true;

      # Use the open source version of the kernel module
      # Only available on driver 515.43.04+
      open = false;

      # Enable the nvidia settings menu
      nvidiaSettings = true;

      # Optionally, you may need to select the appropriate driver version for your specific GPU.
      package = config.boot.kernelPackages.nvidiaPackages.stable;
    };
  };
}
