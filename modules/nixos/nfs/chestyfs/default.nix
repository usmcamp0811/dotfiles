{ options, config, pkgs, lib, ... }:

with lib;
with lib.campground;
let cfg = config.campground.nfs.chestyfs;
in
{
  options.campground.nfs.chestyfs = with types; {
    enable = mkBoolOpt false "Whether or not to mount ChestyFS.";
  };

  config = mkIf cfg.enable {
    fileSystems."/mnt/chestyfs" = {
      device = "chesty:/mnt/chestyfs";
      fsType = "nfs";
      options = [ "rw" "soft" ];
    };
  };
}
