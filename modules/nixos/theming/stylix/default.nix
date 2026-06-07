{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.theming.stylix;
in {
  options.fmf.theming.stylix = with types; {
    enable = mkBoolOpt false "Whether to enable Stylix theming system.";

    theme = mkOpt str "ayu-dark" "Base16 theme name to use (e.g., 'catppuccin-mocha', 'gruvbox-dark-hard', 'ayu-dark').";

    wallpaper = mkOpt (nullOr path) null "Path to wallpaper image. If null, Stylix will generate one from the color scheme.";

    polarity = mkOpt (enum ["dark" "light" "either"]) "dark" "Whether to prefer dark or light themes.";

    fonts = {
      serif = {
        package = mkOpt package pkgs.dejavu_fonts "Serif font package.";
        name = mkOpt str "DejaVu Serif" "Serif font name.";
      };

      sansSerif = {
        package = mkOpt package pkgs.dejavu_fonts "Sans-serif font package.";
        name = mkOpt str "DejaVu Sans" "Sans-serif font name.";
      };

      monospace = {
        package = mkOpt package pkgs.nerd-fonts.fira-code "Monospace font package.";
        name = mkOpt str "FiraCode Nerd Font Mono" "Monospace font name.";
      };

      emoji = {
        package = mkOpt package pkgs.noto-fonts-color-emoji "Emoji font package.";
        name = mkOpt str "Noto Color Emoji" "Emoji font name.";
      };

      sizes = {
        applications = mkOpt int 12 "Font size for applications.";
        terminal = mkOpt int 12 "Font size for terminal.";
        desktop = mkOpt int 10 "Font size for desktop UI.";
        popups = mkOpt int 10 "Font size for popups.";
      };
    };

    cursor = {
      package = mkOpt package pkgs.bibata-cursors "Cursor theme package.";
      name = mkOpt str "Bibata-Modern-Ice" "Cursor theme name.";
      size = mkOpt int 24 "Cursor size.";
    };

    opacity = {
      terminal = mkOpt float 0.95 "Terminal opacity (0.0 to 1.0).";
      applications = mkOpt float 1.0 "Applications opacity (0.0 to 1.0).";
      desktop = mkOpt float 1.0 "Desktop opacity (0.0 to 1.0).";
      popups = mkOpt float 0.95 "Popups opacity (0.0 to 1.0).";
    };

    targets = {
      console.enable = mkBoolOpt true "Theme the virtual console.";
      grub.enable = mkBoolOpt true "Theme GRUB bootloader.";
      gtk.enable = mkBoolOpt true "Theme GTK applications.";
      nixvim.enable = mkBoolOpt false "Theme NixVim (if using nixvim).";
    };
  };

  config = mkIf cfg.enable {
    stylix = {
      enable = true;
      enableReleaseChecks = false;

      # Use base16 scheme by name
      base16Scheme = "${pkgs.base16-schemes}/share/themes/${cfg.theme}.yaml";

      # Wallpaper
      image = mkIf (cfg.wallpaper != null) cfg.wallpaper;

      # Polarity
      polarity = cfg.polarity;

      # Fonts
      fonts = {
        serif = {
          package = cfg.fonts.serif.package;
          name = cfg.fonts.serif.name;
        };

        sansSerif = {
          package = cfg.fonts.sansSerif.package;
          name = cfg.fonts.sansSerif.name;
        };

        monospace = {
          package = cfg.fonts.monospace.package;
          name = cfg.fonts.monospace.name;
        };

        emoji = {
          package = cfg.fonts.emoji.package;
          name = cfg.fonts.emoji.name;
        };

        sizes = {
          applications = cfg.fonts.sizes.applications;
          terminal = cfg.fonts.sizes.terminal;
          desktop = cfg.fonts.sizes.desktop;
          popups = cfg.fonts.sizes.popups;
        };
      };

      # Cursor
      cursor = {
        package = cfg.cursor.package;
        name = cfg.cursor.name;
        size = cfg.cursor.size;
      };

      # Opacity
      opacity = {
        terminal = cfg.opacity.terminal;
        applications = cfg.opacity.applications;
        desktop = cfg.opacity.desktop;
        popups = cfg.opacity.popups;
      };

      # Targets
      targets = {
        console.enable = cfg.targets.console.enable;
        grub.enable = cfg.targets.grub.enable;
        gtk.enable = cfg.targets.gtk.enable;
        nixvim.enable = cfg.targets.nixvim.enable;
      };
    };
  };
}
