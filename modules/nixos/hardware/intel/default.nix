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
    environment.sessionVariables.LIBVA_DRIVER_NAME = "nvidia";
    # environment.sessionVariables.WLR_NO_HARDWARE_CURSORS = "nvidia";

    # systemd.services.NetworkManager-wait-online.enable = false;
    boot = {
      kernelPackages = pkgs.linuxPackages_6_1;
      blacklistedKernelModules = ["nouveau"];
      supportedFilesystems = ["ntfs"];
      # kernelPatches = [
      #   {
      #     name = "nouveau-try";
      #     patch = null;
      #     extraConfig = ''
      #       CONFIG_FRAMEBUFFER_CONSOLE y
      #     '';
      #   }
      # ];
      loader = {
        # systemd-boot.enable = true;
        efi = {
          canTouchEfiVariables = true;
          efiSysMountPoint = "/boot/efi";
        };
        grub = {
          enable = true;
          devices = ["nodev"];
          efiSupport = true;
          useOSProber = true;
        };
      };
    };

    services.upower.enable = true;

    boot.kernelParams = [
      # "nouveau.modeset=1"
      "video=HDMI-A-1:1920x1080@60"
      "nohibernate"
    ];

    hardware.nvidia = {
      open = false;
      modesetting.enable = true;
      powerManagement = {
        enable = true;
        finegrained = true;
      };
      nvidiaSettings = false;
      nvidiaPersistenced = true;
      forceFullCompositionPipeline = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
      prime = {
        offload.enable = true;
        offload.enableOffloadCmd = true;
        intelBusId = "PCI:0:2:0";
        nvidiaBusId = "PCI:1:0:0";
      };
    };
    services.xserver = {
      videoDrivers = ["nvidia"];
      # deviceSection = ''
      #   Option "DRI" "2"
      #   Option "TearFree" "true"
      # '';
    };

    # specialisation = {
    #   nvidiaSync.configuration = {
    #     hardware.nvidia.prime.sync.enable = lib.mkForce true;
    #   };
    # };

    hardware = {
      # bumblebee.enable = true;
      opentabletdriver.enable = true;

      opengl = {
        enable = true;
        driSupport = true;
        driSupport32Bit = true;
        extraPackages = with pkgs; [nvidia-vaapi-driver];
        extraPackages32 = with pkgs.pkgsi686Linux; [nvidia-vaapi-driver];
        # extraPackages = with pkgs; [
        #   intel-media-driver
        #   # vaapiIntel
        #   vaapiVdpau
        #   libvdpau-va-gl
        # ];
        # setLdLibraryPath = true;
        # driSupport = true;
        # extraPackages = with pkgs; [
        #   libglvnd
        #   intel-media-driver
        #   vaapiVdpau
        #   vaapi-intel-hybrid
        #   vaapiIntel
        #   libvdpau-va-gl
        #   nvidia-vaapi-driver
        #   libva
        # ];
      };
    };

    # wake up on external usb devices
    # powerManagement.powerDownCommands = ''
    #   echo enabled > /sys/bus/usb/devices/usb1/power/wakeup
    #   echo enabled > /sys/bus/usb/devices/usb2/power/wakeup
    # '';

    # specialisation = {
    #   external-display.configuration = {
    #     system.nixos.tags = [ "external-display" ];
    #     hardware.nvidia.prime.offload.enable = lib.mkForce false;
    #     hardware.nvidia.powerManagement.enable = lib.mkForce false;
    #   };
    # };


  };
}
