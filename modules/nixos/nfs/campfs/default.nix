{ options, config, pkgs, lib, ... }:

with lib;
with lib.campground;
let cfg = config.campground.nfs.campfs;
in
{
  options.campground.nfs.campfs = with types; {
    enable = mkBoolOpt false "Whether or not to mount campfs.";
  };

  config = mkIf cfg.enable {
    fileSystems."/mnt/campfs" = {
      device = "lucas:/mnt/campfs";
      fsType = "nfs";
      options = [ "rw" "soft" ];
    };
    fileSystems."/mnt/webb" = {
      device = "webb:/webb";
      fsType = "nfs";
      options = [ "rw" "soft" ];
    };
  };
}
