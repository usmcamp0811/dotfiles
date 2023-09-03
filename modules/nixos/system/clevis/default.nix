{ options, config, pkgs, lib, ... }:

with lib;
with lib.campground;
let cfg = config.campground.system.boot;
in
{
  options.campground.system.clevis = with types; {
    enable = mkBoolOpt false "Whether or not to enable Clevis.";
  };

  config = mkIf cfg.enable {
    boot.initrd.extraUtilsCommands = ''
        # clevis dependencies
        copy_bin_and_libs ${pkgs.curl}/bin/curl
        copy_bin_and_libs ${pkgs.bash}/bin/bash
        copy_bin_and_libs ${pkgs.jose}/bin/jose

        # clevis scripts and binaries
        for i in ${pkgs.clevis}/bin/* ${pkgs.clevis}/bin/.clevis-wrapped; do
          copy_bin_and_libs "$i"
        done
    '';
  };
}

