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
    services.xserver.videoDrivers = [ "nvidia" ];
    # services.xserver.videoDrivers = [ "nvidia" "modesetting" ];
    # boot.kernelParams = [ "i915.force_probe=46a6" ];
    boot.initrd.systemd.enable = true;
    hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.stable;



    hardware.nvidia.prime = {
      offload.enable = true;
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };

    # List packages installed in system profile. To search, run:
    # $ nix search wget
    environment.systemPackages = with pkgs; [
      wget
      pciutils
      nvidia-offload
    ];
  };
}
