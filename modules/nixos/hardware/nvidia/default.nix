{ options, config, inputs, pkgs, lib, ... }:

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

      services.udev.extraRules = ''
        KERNEL=="nvidia*", MODE="0666"
      '';

      systemd.services.nvidia-persistenced.serviceConfig.PIDFile = "/run/nvidia-persistenced/nvidia-persistenced.pid";

      services.xserver.extraConfig = ''
        Section "Screen"
          Identifier "Screen-nvidia[0]"
          Device "Device-nvidia[0]"
        EndSection
      '';

    boot = {
      extraModprobeConfig = ''
        option nvidia-drm.modeset=1
      '';
      blacklistedKernelModules = [
        "nouveau"
        "rivafb"
        "nvidiafb"
        "rivatv"
        "nv"
        "uvcvideo"
      ];
      extraModulePackages = [ config.boot.kernelPackages.nvidia_x11 ];
      kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];
      kernelParams = [
        "nouveau.modeset=0"
        "nohibernate"
        "nvidia-drm.modeset=1"
      ];
    };

    services.xserver = {
      videoDrivers = ["nvidia"];
      exportConfiguration = true;
    };

    hardware = {
      nvidia = {
        modesetting.enable = true;
        prime = {
          offload = {
            enable = true;
            enableOffloadCmd = true;
          };
          # sync.enable = true;
          intelBusId = "PCI:0:2:0";
          nvidiaBusId = "PCI:1:0:0";
        };
        package = config.boot.kernelPackages.nvidiaPackages.latest;
        nvidiaPersistenced = true;
      };

      opengl = {
        enable = true;
        driSupport = true;
        extraPackages = with pkgs; [
          intel-media-driver
          vaapiIntel
          vaapiVdpau
          libvdpau-va-gl
          nvidia-vaapi-driver
        ];
      };
    };
  };
}
