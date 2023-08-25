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
   boot = {
    # kernelPackages = pkgs.linuxPackages_zen;
    # extraModulePackages = [ config.boot.kernelPackages.nvidia_x11 ];
    # kernelParams = [ "module_blacklist=i915" ];
    initrd.kernelModules = ["nvidia"];
    # blacklistedKernelModules = [ "nouveau" ];

    # extraModprobeConfig = ''
    #   options bbswitch load_state=-1 unload_state=1 nvidia-drm
    # '';
    #   kernelParams = [
    #     "nouveau.modeset=1"
    #     "nohibernate"
    #     "nvidia-drm.modeset=1"
    #   ];
   };
   services = { 
     tlp.enable = true; 
     auto-cpufreq.enable = true; 
     xserver.videoDrivers = [ "nvidia" ]; 
   }; 
   hardware = { 
     # bumblebee.enable = true;
     nvidia = { 
       open = false; 
       modesetting.enable = true; 
       nvidiaSettings = true;
       prime = { 
         # reverseSync.enable = true;
         offload.enable = true; 
         allowExternalGpu = false;
         intelBusId = "PCI:00:02:0"; 
         nvidiaBusId = "PCI:01:00:0"; 
       }; 
 #      package = pkgs.nvidiaPackages;
       # powerManagement.finegrained = true;
       powerManagement.enable = true;
       package = config.boot.kernelPackages.nvidiaPackages.stable;
     }; 
     opengl = { 
       enable = true; 
       driSupport = true; 
       driSupport32Bit = true; 
       extraPackages = with pkgs; [ 
         intel-media-driver 
         vaapiIntel 
         nvidia-vaapi-driver 
         vaapiVdpau 
         libvdpau-va-gl 
       ]; 
     }; 
     pulseaudio.support32Bit = true; 
   }; 
   environment = { 
     systemPackages = with pkgs; [ 
       nvidia-offload 
       libva 
       libva-utils 
       glxinfo 
     ]; 
   }; 
  };
}
