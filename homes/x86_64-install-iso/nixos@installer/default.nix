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
      env = enabled;
      home-manager = enabled;
      misc = enabled;
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

    tools = {
      git = enabled;
      # The Vault CLI (and consul) with VAULT_ADDR set.
      vault = enabled;
    };
  };

  home.stateVersion = "23.05";
}
