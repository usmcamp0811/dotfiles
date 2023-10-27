{ options, config, pkgs, lib, ... }:

with lib;
with lib.campground;
let cfg = config.campground.nfs.k8s;
in
{
  options.campground.nfs.k8s = with types; {
    enable = mkBoolOpt false "Whether or not to mount k8s.";
  };

  config = mkIf cfg.enable {
    fileSystems."/mnt/k8s" = {
      device = "k8s:/k8s";
      fsType = "nfs";
      options = [ "rw" "soft" ];
    };
  };
}
