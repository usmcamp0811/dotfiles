{ options, config, pkgs, lib, ... }:

with lib;
with lib.campground;
let cfg = config.campground.nfs.client;
in
{
  options.campground.nfs.client = with types; {
    webb = mkBoolOpt false "Whether or not to Webb mount.";
    campfs = mkBoolOpt false "Whether or not to campfs mount.";
    chestyfs = mkBoolOpt false "Whether or not to chestyfs mount.";
    k8s = mkBoolOpt false "Whether or not to k8s mount.";
  
  };

  config = mkIf cfg.webb {
    fileSystems."/mnt/webb" = {
      device = "webb:/webb";
      fsType = "nfs";
      options = [ "rw" "soft" "x-systemd.automount" "noauto" ];
    };
  } // mkIf cfg.campfs {
    fileSystems."/mnt/campfs" = {
      device = "campfs:/campfs";
      fsType = "nfs";
      options = [ "rw" "soft" "x-systemd.automount" "noauto" ];
    };
  } // mkIf cfg.chestyfs {
    fileSystems."/mnt/chestyfs" = {
      device = "chesty:/mnt/chestyfs";
      fsType = "nfs";
      options = [ "rw" "soft" "x-systemd.automount" "noauto" ];
    };
  } // mkIf cfg.k8s {
    fileSystems."/mnt/k8s" = {
      device = "k8s:/k8s";
      fsType = "nfs";
      options = [ "rw" "soft" "x-systemd.automount" "noauto" ];
    };
  };
}


