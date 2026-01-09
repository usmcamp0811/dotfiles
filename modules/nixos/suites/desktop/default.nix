{ options
, config
, lib
, ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.suites.desktop;
in
{
  options.fmf.suites.desktop = with types; {
    enable =
      mkBoolOpt false "Whether or not to enable common desktop configuration.";
  };

  config = mkIf cfg.enable {
    fmf = {
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
            sddmTheme = {
              enable = true;
              name = "cyberpunk";  # You can change this to any of the available themes
            };
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
