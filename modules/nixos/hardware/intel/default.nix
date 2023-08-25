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
    services.xserver = {
      enable = true;
      deviceSection = ''
        Identifier "Intel Graphics"
        Driver "modesetting"
      '';
    };

    boot.kernelModules = [ "bbswitch" ];
    powerManagement.powerUpCommands = ''
      echo OFF > /proc/acpi/bbswitch
    '';    };
  };
}
