{ options
, config
, lib
, pkgs
, ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.desktop.addons.swaynotificationcenter;
in
{
  options.campground.desktop.addons.swaynotificationcenter = {
    enable = mkEnableOption "Hyprpaper";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      swaynotificationcenter
      libnotify
    ];
    # home.file.".config/swaync/config.json".source = lib.cleanSource swayncConfigFile;
    # home.file.".config/swaync/style.css".source = ./config/style.css;
    # home.file.".config/swaync/catppuccin.css".source = ./config/catppuccin.css;
  };
}
