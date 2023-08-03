{ options, config, pkgs, lib, ... }:

with lib;
let 
  cfg = config.campground.hardware.nvidia;
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
    # Setup opengl
    hardware.opengl.enable = true;
    hardware.opengl.driSupport32Bit = true;
    hardware.opengl.extraPackages32 = with pkgs.pkgsi686Linux; [ libva ];

    # Setup external display 
    specialisation = {
      external-display.configuration = {
        system.nixos.tags = [ "external-display" ];
        hardware.nvidia = {
          prime.offload.enable = lib.mkForce false;
          powerManagement.enable = lib.mkForce false;
        };
      };
    };

    boot.initrd.kernelModules = [ "nvidia" ];
    boot.kernelParams = [ "module_blacklist=i915" ];
    # boot.extraModulePackages = [ config.boot.kernelPackages.nvidia_x11 ];

    # Enable the X11 windowing system.
    services.xserver.enable = true;
    services.xserver.displayManager.gdm.enable = true;
    services.xserver.displayManager.gdm.wayland = true;
    services.xserver.displayManager.gdm.nvidiaWayland = true;
    services.xserver.desktopManager.gnome.enable = true;
    services.xserver.videoDrivers = [ "modeset" "nvidia" ];
    hardware.nvidia = {
      powerManagement.enable = true;
      modesetting.enable = true;
      prime = {
        offload.enable = true;
        intelBusId = "PCI:0:2:0";
        nvidiaBusId = "PCI:1:0:0";
      };
    };
    boot.extraModprobeConfig = "options nvidia \"NVreg_DynamicPowerManagement=0x02\"\n";
    services.udev.extraRules = ''
  # Remove NVIDIA USB xHCI Host Controller devices, if present
  ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x0c0330", ATTR{remove}="1"
  
  # Remove NVIDIA USB Type-C UCSI devices, if present
  ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x0c8000", ATTR{remove}="1"
  
  # Remove NVIDIA Audio devices, if present
  ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x040300", ATTR{remove}="1"
  
  # Enable runtime PM for NVIDIA VGA/3D controller devices on driver bind
  ACTION=="bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="auto"
  ACTION=="bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="auto"
  
  # Disable runtime PM for NVIDIA VGA/3D controller devices on driver unbind
  ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="on"
  ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="on"
  '';

    # List packages installed in system profile. To search, run:
    # $ nix search wget
    environment.systemPackages = with pkgs; [
      wget
      pciutils
      nvidia-offload
    ];
  };
}

