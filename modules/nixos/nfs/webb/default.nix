{ options, config, pkgs, lib, ... }:

with lib;
with lib.campground;
let cfg = config.campground.nfs.webb;
in
{
  options.campground.nfs.webb = with types; {
    enable = mkBoolOpt false "Whether or not to mount webb.";
  };

  config = mkIf cfg.enable {
    fileSystems."/mnt/webb" = {
      device = "webb:/webb";
      fsType = "nfs";
      options = [ "rw" "soft" ];
    };
  };
}
