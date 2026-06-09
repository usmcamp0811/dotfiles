{ options
, config
, lib
, pkgs
, ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.desktop.addons.gtk;
  default-attrs = mapAttrs (_key: mkDefault);
  nested-default-attrs = mapAttrs (_key: default-attrs);
in
{
  options.fmf.desktop.addons.gtk = with types; {
    enable = mkBoolOpt false "Whether to customize GTK and apply themes.";
    cursor = {
      name =
        mkOpt str "Catppuccin-Macchiato-Blue-Cursors"
          "The name of the cursor theme to apply.";
      pkg =
        mkOpt package pkgs.catppuccin-cursors.macchiatoBlue
          "The package to use for the cursor theme.";
      size = mkOpt int 32 "The size of the cursor.";
    };
    icon = {
      name = mkOpt str "breeze-dark" "The name of the icon theme to apply.";
      pkg =
        mkOpt package pkgs.libsForQt5.breeze-icons
          "The package to use for the icon theme.";
    };
    theme = {
      name =
        mkOpt str "Catppuccin-Macchiato-Standard-Blue-Dark"
          "The name of the GTK theme to apply.";
      pkg = mkOpt package
        (pkgs.catppuccin-gtk.override {
          accents = [ "blue" ];
          size = "standard";
          variant = "macchiato";
        }) "The package to use for the theme.";
    };
  };
  config = mkIf cfg.enable {
    home.sessionVariables = {
      CURSOR_THEME = cfg.cursor.name;
      GTK_THEME = cfg.theme.name;
      XCURSOR_SIZE = "${toString cfg.cursor.size}";
      XCURSOR_THEME = cfg.cursor.name;
    };

    dconf = {
      enable = true;

      settings = nested-default-attrs {
        "org/gnome/desktop/interface" = {
          color-scheme = "prefer-dark";
          cursor-size = cfg.cursor.size;
          cursor-theme = cfg.cursor.name;
          enable-hot-corners = false;
          font-name = config.fmf.system.fonts.default;
          gtk-theme = cfg.theme.name;
          icon-theme = cfg.icon.name;
        };
      };
    };

    gtk = {
      enable = true;

      cursorTheme = {
        name = mkDefault cfg.cursor.name;
        package = mkDefault cfg.cursor.pkg;
      };

      font = { name = mkDefault config.fmf.system.fonts.default; };

      gtk3.extraConfig = { "gtk-application-prefer-dark-theme" = 1; };

      gtk4.extraConfig = { "gtk-application-prefer-dark-theme" = 1; };

      gtk4.theme = {
        name = cfg.theme.name;
        package = cfg.theme.pkg;
      };

      iconTheme = {
        name = mkDefault cfg.icon.name;
        package = mkDefault cfg.icon.pkg;
      };

      theme = {
        name = mkDefault cfg.theme.name;
        package = mkDefault cfg.theme.pkg;
      };
    };

    home.pointerCursor = {
      name = mkDefault cfg.cursor.name;
      size = mkDefault cfg.cursor.size;
      package = mkDefault cfg.cursor.pkg;
      gtk.enable = true;
      x11.enable = true;
    };
  };
}
