{ options, config, pkgs, lib, ... }:

with lib;
with lib.campground;
let cfg = config.campground.system.zfs;
in
{
  options.campground.system.zfs = with types; {
    enable = mkBoolOpt false "Whether or not to configure zfs.";
    hostId = mkOpt str "12345678" "The output of head -c 8 /etc/machine-id";
  };

  config = mkIf cfg.enable {
    boot.supportedFilesystems = [ "zfs" ];
    boot.zfs.requestEncryptionCredentials = true;
    services.zfs.autoScrub.enable = true;

    networking.hostId = cfg.hostId;
  };
}
