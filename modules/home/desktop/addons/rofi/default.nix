{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let 
  cfg = config.campground.apps.rofi;
in
{
  options.campground.apps.rofi = with types; {
    enable =
      mkBoolOpt false "Whether to enable Rofi in the desktop environment.";
  };

  config = mkIf cfg.enable {

    home.packages = with pkgs; [
      wtype
    ];

    programs.rofi = {
      enable = true;
      package = pkgs.rofi-wayland;

      font = "MonaspiceNe Nerd Font 14";
      location = "center";
      theme = "catppuccin";

      pass = {
        enable = true;
        package = pkgs.rofi-pass-wayland;
      };

      plugins = with pkgs; [
        rofi-calc
        rofi-emoji
        rofi-top
      ];
    };

    xdg.configFile = {
      "rofi" = {
        source = lib.cleanSourceWith {
          src = lib.cleanSource ./config/.;
        };

        recursive = true;
      };
    };
  };

#   config = mkIf cfg.enable {
#
#     home.file.".config/rofi/config.rasi".text = ''
# configuration {
#   show-icons:         true;
#   icon-theme:         "Papirus";
#   location: 0;
#   yoffset: -50;
#   xoffset: -20;
# }
# @import "${pkgs.rofi}/share/rofi/themes/DarkBlue.rasi"
# @theme "${pkgs.rofi}/share/rofi/themes/arthur.rasi"
#     '';
#   };
}

