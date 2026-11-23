# The live user's desktop on the fmf installer ISO: the pieces of my default Hyprland desktop
# (fmf.archetypes.desktop), without the personal applications, the SSH keys and the per-monitor
# settings, none of which belong on an image that boots on someone else's hardware.
{
  lib,
  pkgs,
  config,
  osConfig ? {},
  format ? "unknown",
  ...
}:
with lib;
with lib.fmf; {
  fmf = {
    user = {
      enable = true;
      name = config.snowfallorg.user.name;
    };

    cli = {
      zsh = enabled;
      bash = enabled;
      home-manager = enabled;
    };

    desktop = {
      addons = {
        rofi = enabled;
        wofi = enabled;
        swaynotificationcenter = enabled;
        networkmanagerapplet = enabled;
        swayidle = enabled;
        swaylock = enabled;
        kitty = enabled;
        waybar = enabled;
        hyprpaper = {
          enable = true;
          # An empty monitor name means every monitor, whatever it is called on this hardware.
          monitors = [
            {
              name = "";
              wallpaper = "${pkgs.fmf.wallpapers}/share/wallpapers/hsv-saturnV.jpg";
            }
          ];
          wallpapers = [
            "${pkgs.fmf.wallpapers}/share/wallpapers/hsv-saturnV.jpg"
          ];
        };
      };
      wallpapers = enabled;
      hyprland = {
        enable = true;
        startup = ["${getExe pkgs.networkmanagerapplet}"];
      };
    };

    tools = {git = enabled;};
  };

  # Not `fmf.cli.env`: that is my personal environment (my paths, KUBECONFIG, Julia settings, and my
  # full Neovim as EDITOR, which would add rustc and a JDK to the image).
  home.sessionVariables = {
    EDITOR = mkForce "${pkgs.vim}/bin/vim";
    TERMINAL = "kitty";
    BROWSER = "brave";
  };

  # The Hyprland module defines `$music` (Spotify, 370 MB) and `$editor` (my full Neovim, with rustc and a
  # JDK behind it). Nothing binds either, so point them at something that is already on the image.
  wayland.windowManager.hyprland.settings = {
    "$music" = mkForce "${getExe pkgs.kitty}";
    "$editor" = mkForce "${getExe pkgs.vim}";
  };

  home.stateVersion = "23.05";
}
