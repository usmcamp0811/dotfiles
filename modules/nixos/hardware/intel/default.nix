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

    # systemd.user.services.xrandr-outputsource = {
    #   script = ''
    #     ${pkgs.xorg.xrandr}/bin/xrandr --setprovideroutputsource NVIDIA-0 modesetting && ${pkgs.xorg.xrandr}/bin/xrandr --auto
    #   '';
    #   wantedBy = [ "graphical-session.target" ];
    #   partOf = [ "graphical-session.target" ];
    #   enable = true;
    # };
    # environment.sessionVariables.LIBVA_DRIVER_NAME = "nvidia";
    boot = {
      # kernelPackages = pkgs.linuxPackages_6_1;
      extraModprobeConfig = ''
        options bbswitch load_state=-1 unload_state=1 nvidia-drm
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
      kernelParams = [
        "nouveau.modeset=1"
        "nohibernate"
      ];
    };




    # hardware.nvidia = {
    #   open = false;
    #   modesetting.enable = true;
    #   powerManagement = {
    #     enable = true;
    #     finegrained = true;
    #   };
    #   nvidiaSettings = true;
    #   nvidiaPersistenced = true;
    #   forceFullCompositionPipeline = true;
    #   package = config.boot.kernelPackages.nvidiaPackages.stable;
    #   prime = {
    #     offload.enable = true;
    #     offload.enableOffloadCmd = true;
    #     intelBusId = "PCI:0:2:0";
    #     nvidiaBusId = "PCI:1:0:0";
    #   };
    # };

    services.xserver = {
      videoDrivers = ["nvidia"];
      exportConfiguration = true;
      # deviceSection = ''
      #   Section "OutputClass"
      #       Identifier "intel"
      #       MatchDriver "i915"
      #       Driver "modesetting"
      #   EndSection
      #
      #   Section "OutputClass"
      #       Identifier "nvidia"
      #       MatchDriver "nvidia-drm"
      #       Driver "nvidia"
      #       Option "AllowEmptyInitialConfiguration"
      #       Option "PrimaryGPU" "yes"
      #       ModulePath "/usr/lib/nvidia/xorg"
      #       ModulePath "/usr/lib/xorg/modules"
      #   EndSection
      # '';
    };

    # specialisation = {
    #   nvidiaSync.configuration = {
    #     hardware.nvidia.prime.sync.enable = lib.mkForce true;
    #   };
    # };

    hardware = {
      bluetooth.enable = true;
      pulseaudio.enable = false;
      
      nvidia = {
        modesetting.enable = false;
        prime = {
          reverseSync.enable = true;
          intelBusId = "PCI:0:2:0";
          nvidiaBusId = "PCI:1:0:0";
        };
        package = config.boot.kernelPackages.nvidiaPackages.stable;
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
