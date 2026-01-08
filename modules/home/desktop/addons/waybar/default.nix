{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.desktop.addons.waybar;

  theme = builtins.readFile ./styles/catppuccin.css;
  style = builtins.readFile ./styles/style.css;
  notificationsStyle = builtins.readFile ./styles/notifications.css;
  powerStyle = builtins.readFile ./styles/power.css;
  statsStyle = builtins.readFile ./styles/stats.css;
  workspacesStyle = builtins.readFile ./styles/workspaces.css;

  custom-modules =
    import ./modules/custom-modules.nix {inherit config lib pkgs;};
  default-modules = import ./modules/default-modules.nix {inherit lib pkgs;};
  group-modules = import ./modules/group-modules.nix;
  hyprland-modules =
    import ./modules/hyprland-modules.nix {inherit config lib;};

  all-modules = mkMerge [
    custom-modules
    default-modules
    group-modules
    (lib.mkIf config.fmf.desktop.hyprland.enable hyprland-modules)
  ];

  bar = {
    "layer" = "top";
    "position" = "top";

    "modules-left" = [
      # "group/power"
      "hyprland/workspaces"
      "hyprland/window"
    ];
  };

  # TODO: make bars an option that gets passed in maybe so you can specify multiple monitors
  mainBar = {
    # "output" = cfg.display;
    # "modules-center" = [ "mpris" ];

    "modules-right" = [
      "group/tray"
      "group/stats"
      "group/notifications"
      "hyprland/submap"
      "custom/weather"
      "clock"
    ];
  };

  # Fetch waybar themes from dots-hypr repo
  waybarThemes = pkgs.fetchgit {
    url = "https://github.com/raman164/dots-hypr.git";
    rev = "refs/heads/main";
    hash = "sha256-wan3PZK33823nLZvnHkWYOiXdY8p2P5BL7pu6GY36LI=";
    sparseCheckout = [".config/waybar/themes"];
  };
in {

  options.fmf.desktop.addons.waybar = with types; {
    enable =
      mkBoolOpt false "Whether to enable gBar in the desktop environment.";
    display = mkOpt str "DP-1" "the name of the output";
    enableThemeSwitcher = mkBoolOpt true "Enable waybar theme switcher with multiple themes";
  };

  config = mkIf cfg.enable {
    # systemd.user.services.waybar.Service.ExecStart = mkIf cfg.debug (mkForce "${getExe config.programs.waybar.package} -l debug");

    programs.waybar = {
      enable = true;
      # package = nixpkgs-wayland.packages.${system}.waybar;
      package = pkgs.waybar;
      systemd.enable = true;

      # TODO: make dynamic / support different number of bars etc
      settings = {
        mainBar = mkMerge [bar mainBar all-modules];
        # secondaryBar = mkMerge [ bar secondaryBar all-modules ];
      };

      style = "${theme}${style}${notificationsStyle}${powerStyle}${statsStyle}${workspacesStyle}";
    };

    # Install waybar themes and theme switcher
    home.file = mkIf cfg.enableThemeSwitcher {
      # Copy all themes from dots-hypr repo
      ".config/waybar/themes-available" = {
        source = "${waybarThemes}/.config/waybar/themes";
        recursive = true;
      };

      # Save current/default theme
      ".config/waybar/themes-available/default/config" = {
        text = builtins.toJSON (mkMerge [bar mainBar all-modules]);
      };

      ".config/waybar/themes-available/default/style.css" = {
        text = "${theme}${style}${notificationsStyle}${powerStyle}${statsStyle}${workspacesStyle}";
      };

      # Theme switcher script
      ".local/bin/waybar-theme-switcher" = {
        executable = true;
        text = ''
          #!/usr/bin/env bash

          THEMES_DIR="$HOME/.config/waybar/themes-available"
          WAYBAR_CONFIG="$HOME/.config/waybar"

          # List available themes
          THEME=$(ls "$THEMES_DIR" | ${getExe pkgs.rofi} -dmenu -p "Select Waybar Theme")

          if [ -n "$THEME" ]; then
            # Backup home-manager generated files if they're not symlinks
            if [ ! -L "$WAYBAR_CONFIG/config" ]; then
              cp "$WAYBAR_CONFIG/config" "$WAYBAR_CONFIG/config.hm-backup" 2>/dev/null || true
            fi
            if [ ! -L "$WAYBAR_CONFIG/style.css" ]; then
              cp "$WAYBAR_CONFIG/style.css" "$WAYBAR_CONFIG/style.css.hm-backup" 2>/dev/null || true
            fi

            # Create symlinks to selected theme
            ln -sf "$THEMES_DIR/$THEME/config" "$WAYBAR_CONFIG/config"
            ln -sf "$THEMES_DIR/$THEME/style.css" "$WAYBAR_CONFIG/style.css"

            # Reload waybar
            systemctl --user restart waybar.service

            ${getExe pkgs.libnotify} "Waybar Theme" "Switched to theme: $THEME"
          fi
        '';
      };
    };
  };
}
