{
  pkgs,
  options,
  config,
  lib,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.suites.desktop;
in {
  options.fmf.suites.desktop = with types; {
    enable =
      mkBoolOpt false "Whether or not to enable common desktop configuration.";
    theme = mkOpt str "da-one-black" "Sylix theme to use";
  };

  config = mkIf cfg.enable {
    fmf = {
      theming.stylix = {
        enable = true;
        wallpaper = "${pkgs.fmf.wallpapers}/share/wallpapers/pittsburgh-wallpaper.jpeg";
        theme = cfg.theme;
        # Optional: customize fonts to match your current kitty config
        fonts.monospace = {
          package = pkgs.nerd-fonts.fira-code;
          name = "FiraCode Nerd Font Mono";
        };
        # Optional: match your kitty opacity
        opacity.terminal = 0.95;
      };
      desktop = {
        addons = {
          wallpapers = enabled;
          kitty = enabled;
          swaylock = enabled;
          swappy = enabled;
        };
        display-manager = {
          # gdm = {
          #   enable = true;
          #   wayland = true;
          # };
          sddm = {
            enable = true;
            wayland = true;
            theme = "sddm-astronaut-theme";
            # sddmTheme = {
            #   enable = true;
            #   # name can be overridden per-system
            # };
          };
        };
        hyprland = enabled;
        qtile = enabled;
      };
      apps = {
        # _1password = enabled;
        # firefox = enabled;
        # vlc = enabled;
        # logseq = enabled;
        # hey = enabled;
        # pocketcasts = enabled;
        # yt-music = enabled;
        # twitter = enabled;
        # gparted = enabled;
      };
    };
  };
}
