{ options, config, pkgs, lib, ... }:

with lib;
let cfg = config.campground.hardware.nvidia;
in
{
  options.campground.hardware.nvidia = with types; {
    enable = mkEnableOption "Nvidia support";
  };

  config = mkIf cfg.enable {
    services.xserver.displayManager.sessionCommands = ''
        ${lib.getBin pkgs.xorg.xrandr}/bin/xrandr --setprovideroutputsource 2 0
    '';
    specialisation = {
      external-display.configuration = {
        system.nixos.tags = [ "external-display" ];
        hardware.nvidia = {
          prime.sync.enable = lib.mkForce true;
          powerManagement.enable = lib.mkForce false;
        };
      };
    };

    services.xserver.videoDrivers = ["nvidia"];

    hardware.nvidia = {
      # Modesetting should be enabled to prevent screen tearing
      modesetting.enable = true;

      # Reverse sync is not compatible with the open source kernel module
      open = false;

      prime = {
        sync.enable = true; # Enable PRIME Sync instead of Reverse Sync

        #enable if using an external GPU
        allowExternalGpu = false;

        intelBusId = "PCI:0:2:0";

        nvidiaBusId = "PCI:1:0:0";
      };
    };
  };
}

