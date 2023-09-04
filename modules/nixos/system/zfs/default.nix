{ options, config, pkgs, lib, ... }:

with lib;
with lib.campground;
let 
  cfg = config.campground.system.zfs;
  hostIdFromFile = pkgs.runCommand "get-hostId" {} ''
    head -c 8 /etc/machine-id > $out
  '';
in
{
  options.campground.system.zfs = with types; {
    enable = mkBoolOpt false "Whether or not to configure zfs.";
    hostId = mkOpt str builtins.readFile hostIdFromFile "The output of head -c 8 /etc/machine-id";
  };

  config = mkIf cfg.enable {
    boot.supportedFilesystems = [ "zfs" ];
    boot.zfs.requestEncryptionCredentials = true;
    services.zfs.autoScrub.enable = true;

    networking.hostId = cfg.hostId;
  };
}
