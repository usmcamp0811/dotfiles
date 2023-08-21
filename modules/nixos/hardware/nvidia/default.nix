{ options, config, pkgs, lib, ... }:

with lib;
let
  cfg = config.campground.hardware.nvidia;
in
{
  options.campground.hardware.nvidia = with types; {
    enable = mkEnableOption "Nvidia support";
  };

  config = mkIf cfg.enable {
    # boot.kernelParams = [ "module_blacklist=i915" ]; # blacklist integrated gpu
    # boot.extraModulePackages = [ config.boot.kernelPackages.nvidia_x11 ];

    services.xserver = {
      videoDrivers = ["nvidia" "modesetting" "fbdev" ];
      exportConfiguration = true;
      modules = [pkgs.xorg.xf86videointel];
    };
    hardware = {
      opengl = {
        enable = true;
        driSupport = true;
        driSupport32Bit = true; # Required for steam
      };
      nvidia = {
        modesetting.enable = true; # required for native resolution in TTY
        powerManagement.enable = true;
        open = false;
        nvidiaSettings = true;
        package = config.boot.kernelPackages.nvidiaPackages.vulkan_beta; # stable, production, latest, beta, or vulkan_beta
        #Fixes a glitch
        nvidiaPersistenced = true;
        prime = {
            offload.enable = true;
            #sync.enable = true;
            intelBusId = "PCI:0:2:0";
            nvidiaBusId = "PCI:1:0:0";
        };
      };
    };
    systemd.user.services.xrandr-outputsource = {
      script = ''
        ${pkgs.xorg.xrandr}/bin/xrandr --setprovideroutputsource NVIDIA-0 modesetting && ${pkgs.xorg.xrandr}/bin/xrandr --auto
      '';
      wantedBy = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      enable = true;
    };
  };
}
