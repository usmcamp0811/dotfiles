{ options, config, inputs, pkgs, lib, ... }:

with lib;
let
  cfg = config.campground.hardware.nvidia-prime;
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
    exec -a "$0" "$@"
  '';
in
{
  options.campground.hardware.nvidia-prime = with types; {
    enable = mkEnableOption "Nvidia support";
  };

  config = mkIf cfg.enable {

    environment.systemPackages = with pkgs; [
      nvidia-offload
      pciutils
    ];

    services.xserver = {         
      videoDrivers = ["nvidia"]; 
      exportConfiguration = true;
      displayManager = {
        startx = {
          enable = true;
        };
      };
    };  

    hardware = {
      nvidia = {
        powerManagement.enable = lib.mkForce false;
        modesetting.enable = true;
        prime = {
          offload.enable = true; # enable to use intel gpu (hybrid mode)
          sync.enable = false; # enable to use nvidia gpu (discrete mode)
          intelBusId = "PCI:0:2:0";
          nvidiaBusId = "PCI:1:0:0";
        };
      };

      # other opengl stuff is included via <nixos-hardware/common/cpu/intel> (including 
      # intel-media-driver and vaapiIntel)
      opengl = {
        enable = true;
        extraPackages = with pkgs; [ 
          intel-media-driver         
          vaapiIntel                 
          vaapiVdpau                 
          libvdpau-va-gl             
          nvidia-vaapi-driver        
        ];                           
        driSupport = true;
        driSupport32Bit = true;
      };
    };
  };
}



