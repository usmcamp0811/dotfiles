{ options, config, pkgs, lib, ... }:

with lib;
let
  cfg = config.campground.hardware.nvidia;
  displaySetupScript = pkgs.writeShellScript "display_setup.sh" ''
    #!/bin/sh
    ${pkgs.xorg.xrandr}/bin/xrandr --setprovideroutputsource NVIDIA-0
    ${pkgs.xorg.xrandr}/bin/xrandr --auto
  '';
in
{
  options.campground.hardware.nvidia = with types; {
    enable = mkEnableOption "Nvidia support";
  };

  config = mkIf cfg.enable {
    # boot.kernelParams = [ "nvidia-drm.modeset=1"]; # blacklist integrated gpu
    # boot.kernelParams = ["nouveau.modeset=0" "pci=nommconf" "nvidia-drm.modeset=1" "i915.enable_psr=0"];
    boot.kernelParams = ["blacklist.nouveau=1" "i915.modeset=1"];

    # boot.initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];
    # boot.extraModulePackages = with config.boot.kernelPackages; [ acpi_call nvidia_x11 ];
    # boot.kernelModules = [ "acpi_call" ];
    # boot.kernelParams = [ "i915.force_probe=9a60" ];
#     services.udev.extraRules =
#       ''
# # Enable runtime PM for NVIDIA VGA/3D controller devices on driver bind
# ACTION=="bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="auto"
# ACTION=="bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="auto"
#
# # Disable runtime PM for NVIDIA VGA/3D controller devices on driver unbind
# ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="on"
# ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="on"
#       '';
#
    environment.etc."X11/xorg.conf.d/20-intel.conf".text = ''
      Section "Device"
          Identifier "intelgpu0"
          Driver "intel"
          Option "VirtualHeads" "2"
      EndSection
    '';
  
    # services.xserver.displayManager.startx.enable = true;
    environment.systemPackages = with pkgs; [ xorg.xrandr ];

    services.xserver = {
      videoDrivers = [ "nvidia" ];
      exportConfiguration = true;
      modules = [pkgs.xorg.xf86videointel];
      # displayManager.lightdm = {
      #   enable = true;
      #   extraConfig = ''
      #     [Seat:*]
      #     display-setup-script=${displaySetupScript}
      #   '';
      # };
    };
    hardware = {
      opengl = {
        enable = true;
        driSupport = true;
        driSupport32Bit = true; # Required for steam
        extraPackages = with pkgs; [
          vaapiIntel         # LIBVA_DRIVER_NAME=i965 (older but works better for Firefox/Chromium)
          vaapiVdpau

          (if (lib.versionOlder (lib.versions.majorMinor lib.version) "23.11") then vaapiIntel else intel-vaapi-driver)
          libvdpau-va-gl
          intel-media-driver
        ];
      };
      nvidia = {
        modesetting.enable = true; # required for native resolution in TTY
        powerManagement.enable = true;
        open = false;
        nvidiaSettings = true;
        package = config.boot.kernelPackages.nvidiaPackages.stable; # stable, production, latest, beta, or vulkan_beta
        #Fixes a glitch
        nvidiaPersistenced = true;
        prime = {
            offload.enable = true;
            # sync.enable = true;
            intelBusId = "PCI:0:2:0";
            nvidiaBusId = "PCI:1:0:0";
        };
      };
    };
  hardware.cpu.intel.updateMicrocode =
    lib.mkDefault config.hardware.enableRedistributableFirmware;
  # boot.blacklistedKernelModules = lib.mkDefault [ "i915" ];

  environment.variables = {
    VDPAU_DRIVER = lib.mkIf config.hardware.opengl.enable (lib.mkDefault "va_gl");
  };


  services.fprintd.enable = true;
    # systemd.user.services.xrandr-outputsource = {
    #   script = ''
    #     ${pkgs.xorg.xrandr}/bin/xrandr --setprovideroutputsource NVIDIA-G0 modesetting && ${pkgs.xorg.xrandr}/bin/xrandr --auto
    #   '';
    #   wantedBy = [ "graphical-session.target" ];
    #   partOf = [ "graphical-session.target" ];
    #   enable = true;
    # };
  };
}
