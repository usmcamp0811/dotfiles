{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let 
  cfg = config.campground.services.syncthing;
in
{
  options.campground.services.syncthing = with types; {
    enable = mkBoolOpt false "Whether or not to enable syncthing.";
  };

  config = mkIf cfg.enable {
    programs.syncthing = {
      enable = true;
      # openDefaultPorts = true;
      # user = config.campground.user.name;
      # deviceName = "MyDevice";
      # extraConfig = {
      #   someOption = "someValue";
      # };
    };
  };
}

