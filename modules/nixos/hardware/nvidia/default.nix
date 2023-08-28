{ options, config, pkgs, lib, ... }:

with lib;
let
  cfg = config.campground.hardware.nvidia;
  displaySetupScript = pkgs.writeShellScript "display_setup.sh" ''
    #!/bin/sh
    ${pkgs.xorg.xrandr}/bin/xrandr --setprovideroutputsource NVIDIA-G0
    ${pkgs.xorg.xrandr}/bin/xrandr --auto
  '';
  nvidia-offload = pkgs.writeShellScriptBin "nvidia-offload" '' 
     export __NV_PRIME_RENDER_OFFLOAD=1 
     export __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0 
     export __GLX_VENDOR_LIBRARY_NAME=nvidia 
     export __VK_LAYER_NV_optimus=NVIDIA_only 
     exec "$@" 
   '';
in
{
  options.campground.hardware.nvidia = with types; {
    enable = mkEnableOption "Nvidia support";
  };

  config = mkIf cfg.enable {

    boot.blacklistedKernelModules = [ "nvidiafb" ];
    # Enable OpenGL
    hardware.opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
    };

    # Load nvidia driver for Xorg and Wayland
    services.xserver.videoDrivers = ["nvidia"];
    hardware.nvidia = {

      # Modesetting is needed most of the time
      modesetting.enable = false;

    # Enable power management (do not disable this unless you have a reason to).
    # Likely to cause problems on laptops and with screen tearing if disabled.
      powerManagement.enable = true;
      forceFullCompositionPipeline = true;
      # Use the open source version of the kernel module ("nouveau")
    # Note that this offers much lower performance and does not
    # support all the latest Nvidia GPU features.
    # You most likely don't want this.
      # Only available on driver 515.43.04+
      open = false;

      # Enable the Nvidia settings menu,
    # accessible via `nvidia-settings`.
      nvidiaSettings = true;

      # Optionally, you may need to select the appropriate driver version for your specific GPU.
      # package = config.boot.kernelPackages.nvidiaPackages.stable;
      package = config.boot.kernelPackages.nvidiaPackages.stable;

      prime = {
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };
        # Make sure to use the correct Bus ID values for your system!
        intelBusId = "PCI:0:2:0";
        nvidiaBusId = "PCI:1:0:0";
      };
    };
  };
}
