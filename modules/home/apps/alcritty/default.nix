{ lib, config, pkgs, ... }:

let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.campground.cli.alcritty;
in
{
  options.campground.cli.alcritty = {
    enable = mkEnableOption "Alacritty";
  };

  config = mkIf cfg.enable {
    programs.alacritty = {
      enable = true;

      font = {
        normal.family = "FiraCode Nerd Font Mono";
        normal.style = "Regular";
        bold.family = "FiraCode Nerd Font Mono";
        bold.style = "Light Bold";
        italic.family = "SourceCodePro";
        italic.style = "Light Italic";
        size = 8;
        offset.x = 0;
        offset.y = 0;
        glyphOffset.x = 0;
        glyphOffset.y = 0;
      };

      colors = {
        primary.background = "0x0A0E14";
        primary.foreground = "0xB3B1AD";
        primary.dimForeground = "0xdbdbdb";
        primary.brightForeground = "0xd9d9d9";
        primary.dimBackground = "0x202020";
        primary.brightBackground = "0x3a3a3a";
        normal.black = "0x01060E";
        normal.red = "0xEA6C73";
        normal.green = "0x91B362";
        normal.yellow = "0xF9AF4F";
        normal.blue = "0x53BDFA";
        normal.magenta = "0xFAE994";
        normal.cyan = "0x90E1C6";
        normal.white = "0xC7C7C7";
        normal.orange = "0xcc6953";
        bright.black = "0x686868";
        bright.red = "0xF07178";
        bright.green = "0xC2D94C";
        bright.yellow = "0xFFB454";
        bright.blue = "0x59C2FF";
        bright.magenta = "0xFFEE99";
        bright.cyan = "0x95E6CB";
        bright.white = "0xFFFFFF";
        cursor.text = "0x122637";
        cursor.cursor = "0xf0cb09";
        dim.black = "0x232323";
        dim.red = "0x74423f";
        dim.green = "0x5e6547";
        dim.yellow = "0x8b7653";
        dim.blue = "0x556b79";
        dim.magenta = "0x6e4962";
        dim.cyan = "0x5c8482";
        dim.white = "0x828282";
      };

      bell = {
        animation = "EaseOutExpo";
        duration = 1;
        color = "#7a8530";
      };

      window = {
        opacity = 0.9;
        dynamicTitle = true;
      };

      cursor = {
        style = "Block";
        unfocusedHollow = true;
      };

      liveConfigReload = true;

      shell.program = "/bin/alcritty";

      hints = {
        doubleClick.threshold = 300;
        url.launcher.program = "firefox";
      };

      keyBindings = [
        { key = "V"; mods = "Control|Shift"; action = "Paste"; }
        { key = "C"; mods = "Control|Shift"; action = "Copy"; }
        { key = "Key0"; mods = "Control"; action = "ResetFontSize"; }
        { key = "Equals"; mods = "Control"; action = "IncreaseFontSize"; }
        { key = "Minus"; mods = "Control"; action = "DecreaseFontSize"; }
      ];
    };
  };
}
