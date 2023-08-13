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
    services.xserver.enable = true;
    services.xserver.videoDrivers = [ "displaylink" "nvidia" ];
    boot.kernelParams = [ "i915.force_probe=46a6" ];
    # boot.initrd.systemd.enable = true; # this seemed to be the secret to nvidia-prime working... I think
    boot.initrd.kernelModules = [ "i915" ];
    # boot.kernelParams = [ "module_blacklist=i915" ];
    boot.extraModulePackages = [ config.boot.kernelPackages.nvidia_x11 ];

    # hardware.nvidia.powerManagement.finegrained = true;

    hardware = {
      opengl = {
        enable = true;
         driSupport = true;
         driSupport32Bit = true;
      };
      nvidia = {
        package = config.boot.kernelPackages.nvidiaPackages.stable;
        nvidiaPersistenced = true;
        modesetting.enable = true;
        powerManagement.enable=true;
        prime = {
          offload.enable = true;
          # sync.enable = true;
          # reverseSync.enable = true;
          # offload.enableOffloadCmd = true;
          intelBusId = "PCI:0:2:0";
          nvidiaBusId = "PCI:1:0:0";
        };
      };
    };
    services.tlp = {
      enable = true;
      settings = {
        TLP_DEFAULT_MODE = "BAT";
        TLP_PERSISTENT_DEFAULT = 1;
      };
    };


    specialisation = {
      external-display.configuration = {
        system.nixos.tags = [ "external-display" ];
        hardware.nvidia = {
          prime.offload.enable = lib.mkForce false;
          powerManagement.enable = lib.mkForce false;
        };
      };
    };
    # List packages installed in system profile. To search, run:
    # $ nix search wget
    environment.systemPackages = with pkgs; [
      wget
      pciutils
      nvidia-offload
      glxinfo
    ];
  };
}
