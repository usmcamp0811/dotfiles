{
  lib,
  pkgs,
  config,
  osConfig ? {},
  format ? "unknown",
  ...
}:
with lib.fmf; {
  fmf = {
    user = {
      enable = true;
      name = config.snowfallorg.user.name;
    };

    cli = {
      zsh = enabled;
      home-manager = enabled;
      env = enabled;
    };
    # desktop = {
    #   wallpapers = enabled;
    #   qtile = {
    #     enable = true;
    #     wallpaper = "hsv-saturnV.png";
    #   };
    # };
    # apps = {
    # qutebrowser = enabled;
    # kitty = enabled;
    # rofi = enabled;
    # };
  };
  home.stateVersion = "23.05";
}
