{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.macos-vm;
  inherit (pkgs.campground) mlflow;
in
{
  options.campground.services.macos-vm = with types; {
    enable = mkBoolOpt false "Enable an MacOS VM;";
  };

  config = mkIf cfg.enable {

    users.users.macos-ventura = {
      isSystemUser = true;
      group = "macos-ventura";
    };
    users.groups.macos-ventura = { };

    campground.nix.additional-authorized-users = [ "macos-ventura" ];
    services.macos-ventura = {
      enable = true;
      openFirewall = true;
      vncListenAddr = "0.0.0.0";
    };
  };
}
