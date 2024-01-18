{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let 
  cfg = config.campground.desktop.addons.swaynotificationcenter;
  swayncConfig = import ./config.nix { inherit pkgs; };
  swayncConfigFile = pkgs.writeTextFile {
    name = "swaync-config.json";
    text = builtins.toJSON swayncConfig;
  };
in
{
  options.campground.desktop.addons.swaynotificationcenter = {
    enable = mkEnableOption "Hyprpaper";
  };

  config = mkIf cfg.enable { 

    home.packages = with pkgs; [
      swaynotificationcenter
      libnotify
    ];
# TODO: Nixifiy the config.json so we can get the correct paths to things
    home.file.".config/swaync/config.json".source = swayncConfigFile;
    xdg.configFile = {
      "swaync" = {
        source = lib.cleanSourceWith {
          src = lib.cleanSource ./config/.;
        };

        recursive = true;
      };
    };
  };
}

