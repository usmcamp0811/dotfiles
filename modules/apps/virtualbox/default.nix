{ options, config, lib, pkgs, ... }:

with lib;
with lib.internal;
let
  cfg = config.campground.apps.virtualbox;
in
{
  options.campground.apps.virtualbox = with types; {
    enable = mkBoolOpt false "Whether or not to enable Virtualbox.";
  };

  config = mkIf cfg.enable {
    campground.virtualisation.virtualbox.host = {
      enable = true;
      enableExtensionPack = true;
    };

    campground.user.extraGroups = [ "vboxusers" ];
  };
}
