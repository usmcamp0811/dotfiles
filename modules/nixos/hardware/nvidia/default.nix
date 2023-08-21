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
    boot.kernelParams = [ "module_blacklist=i915" ]; # blacklist integrated gpu
    boot.extraModulePackages = [ config.boot.kernelPackages.nvidia_x11 ];
boot = {
        blacklistedKernelModules = ["nouveau" "nvidiafb"];
        services.udev.extraRules =
        ''
          # Create /dev/nvidia-uvm when the nvidia-uvm module is loaded.
          KERNEL=="nvidia", RUN+="${pkgs.runtimeShell} -c 'mknod -m 666 /dev/nvidiactl c $$(grep nvidia-frontend /proc/devices | cut -d \  -f 1) 255'"
          KERNEL=="nvidia", RUN+="${pkgs.runtimeShell} -c 'for i in $$(cat /proc/driver/nvidia/gpus/*/information | grep Minor | cut -d \  -f 4); do mknod -m 666 /dev/nvidia$${i} c $$(grep nvidia-frontend /proc/devices | cut -d \  -f 1) $${i}; done'"
          KERNEL=="nvidia_modeset", RUN+="${pkgs.runtimeShell} -c 'mknod -m 666 /dev/nvidia-modeset c $$(grep nvidia-frontend /proc/devices | cut -d \  -f 1) 254'"
          KERNEL=="nvidia_uvm", RUN+="${pkgs.runtimeShell} -c 'mknod -m 666 /dev/nvidia-uvm c $$(grep nvidia-uvm /proc/devices | cut -d \  -f 1) 0'"
          KERNEL=="nvidia_uvm", RUN+="${pkgs.runtimeShell} -c 'mknod -m 666 /dev/nvidia-uvm-tools c $$(grep nvidia-uvm /proc/devices | cut -d \  -f 1) 1'"
        ''
        + lib.optionalString cfg.powerManagement.finegrained (
          lib.optionalString (lib.versionOlder config.boot.kernelPackages.kernel.version "5.5") ''
            # Remove NVIDIA USB xHCI Host Controller devices, if present
            ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x0c0330", ATTR{remove}="1"

            # Remove NVIDIA USB Type-C UCSI devices, if present
            ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x0c8000", ATTR{remove}="1"

            # Remove NVIDIA Audio devices, if present
            ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x040300", ATTR{remove}="1"
          ''
          + ''
            # Enable runtime PM for NVIDIA VGA/3D controller devices on driver bind
            ACTION=="bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="auto"
            ACTION=="bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="auto"

            # Disable runtime PM for NVIDIA VGA/3D controller devices on driver unbind
            ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="on"
            ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="on"
          ''
        );
    };
    services.xserver = {
      videoDrivers = ["nvidia" "modesetting" ];
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
      exportConfiguration = true;
      videoDrivers = [ "nvidia" "displaylink" ];
    };

  };
  # boot.extraModulePackages = [ config.boot.kernelPackages.nvidia_x11 ];

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
  boot.kernelPackages = pkgs.linuxPackages_latest;

  hardware = {
    nvidia = {
      modesetting.enable = true;
      powerManagement.enable = true;
      powerManagement.finegrained = false;
      prime = {
        offload.enable = true;
        intelBusId = "PCI:0:2:0";
        nvidiaBusId = "PCI:1:0:0";
      };
      package = config.boot.kernelPackages.nvidiaPackages.stable;
    };

    opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
    };

  };
   environment.systemPackages = with pkgs; [
     wget
     pciutils
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
