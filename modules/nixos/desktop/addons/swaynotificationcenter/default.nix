{ options
, config
, lib
, pkgs
, ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.desktop.addons.swaynotificationcenter;
in
{
  options.fmf.desktop.addons.swaynotificationcenter = {
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
