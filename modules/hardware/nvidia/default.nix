{ options, config, pkgs, lib, ... }:

with lib;
let
  cfg = config.campground.hardware.nvidia;
  nvidia-offload = pkgs.writeShellScriptBin "nvidia-offload" ''
    export __NV_PRIME_RENDER_OFFLOAD=1
    export __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0
    export __GLX_VENDOR_LIBRARY_NAME=nvidia
    export __VK_LAYER_NV_optimus=NVIDIA_only
    exec -a "$0" "$@"
  '';
in
{
  options.campground.hardware.nvidia = with types; {
    enable = mkEnableOption "Nvidia support";
  };

  config = mkIf cfg.enable {
  services = {
    xserver = {
      enable = true;
      exportConfiguration = true;
      videoDrivers = [ "nvidia" "displaylink" ];
    };

  };

  # set output source to Nvidia for HDMI port
  systemd.user.services.xrandr-outputsource = {
    script = ''
      ${pkgs.xorg.xrandr}/bin/xrandr --setprovideroutputsource NVIDIA-G0 modesetting && ${pkgs.xorg.xrandr}/bin/xrandr --auto
    '';
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    enable = true;
  };
  # services.xserver.displayManager.setupCommands = ''
  #   ${pkgs.lib.getBin pkgs.xorg.xrandr}/bin/xrandr --setprovideroutsource modesetting NVIDIA-0
  #   ${pkgs.lib.getBin pkgs.xorg.xrandr}/bin/xrandr --auto
  # '';

  hardware = {
    nvidia = {
      modesetting.enable = false;
      prime = {
        offload.enable = true;
        intelBusId = "PCI:0:2:0";
        nvidiaBusId = "PCI:1:0:0";
      };
    };

    opengl = {
      driSupport = true;
      driSupport32Bit = true;
    };

  };
   environment.systemPackages = with pkgs; [
     wget
     pciutils
     nvidia-offload
     glxinfo
   ];

#     services.xserver.enable = true;
#     # services.xserver.videoDrivers = [ "displaylink" "nvidia" ];
#     # services.xserver.videoDrivers = [ "nvidia" ];
#     services.xserver.videoDrivers = [ "nvidia" "displaylink" "modesetting" ];
#     # boot.kernelParams = [ "i915.force_probe=46a6" ];
#     # boot.initrd.systemd.enable = true; # this seemed to be the secret to nvidia-prime working... I think
#     # boot.initrd.kernelModules = [ "i915" "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm"];
#     # boot.kernelParams = [ "module_blacklist=i915" ];
#     boot.extraModulePackages = [ config.boot.kernelPackages.nvidia_x11 ];
# 
#   # Need to set Thunderbolt to "BIOS Assist Mode"
#   # https://forums.lenovo.com/t5/Other-Linux-Discussions/T480-CPU-temperature-and-fan-speed-under-linux/m-p/4114832
#     boot.kernelParams = [ "acpi_backlight=native" ];
# 
#     hardware = {
#       opengl = {
#         enable = true;
#          driSupport32Bit = true;
#       };
#       nvidia = {
#         open = true;
#         # package = config.boot.kernelPackages.nvidiaPackages.stable;
#         # package = config.boot.kernelPackages.nvidiaPackages.legacy_470;
#         nvidiaPersistenced = true;
#         modesetting.enable = true;
#         powerManagement.enable=false;
#         # powerManagement.finegrained = true;
#         prime = {
#           offload.enable = true;
#           #offload.enable = false;
#           # sync.enable = true;
#           # reverseSync.enable = true;
#           # offload.enableOffloadCmd = true;
#           intelBusId = "PCI:0:2:0";
#           nvidiaBusId = "PCI:1:0:0";
#         };
#       };
#     };
#     services.tlp = {
#       enable = true;
#       settings = {
#         TLP_DEFAULT_MODE = "BAT";
#         TLP_PERSISTENT_DEFAULT = 1;
#       };
#     };
#     boot.plymouth.enable = true;
#     # services.xserver.displayManager.setupCommands = ''
#     #   ${pkgs.lib.getBin pkgs.xorg.xrandr}/bin/xrandr --setprovideroutsource modesetting NVIDIA-0
#     #   ${pkgs.lib.getBin pkgs.xorg.xrandr}/bin/xrandr --auto
#     # '';
# 
#     # specialisation = {
#     #   external-display.configuration = {
#     #     system.nixos.tags = [ "external-display" ];
#     #     hardware.nvidia = {
#     #       prime.offload.enable = lib.mkForce false;
#     #       powerManagement.enable = lib.mkForce false;
#     #     };
#     #   };
#     # };
#     # List packages installed in system profile. To search, run:
#     # $ nix search wget
  };
}
