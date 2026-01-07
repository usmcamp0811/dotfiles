{ options, config, lib, pkgs, ... }:
with lib;
with lib.fmf;
let
  cfg = config.fmf.desktop.addons.qt;
  settings = {
    Appearance = {
      color_scheme_path = "";
      custom_palette = true;
      icon_theme = config.fmf.desktop.addons.gtk.icon.name;
      standard_dialogs = "gtk3";
      style = "kvantum";
    };

    Fonts = {
      fixed = "MonaspiceKr Nerd Font 10";
      general = "MonaspiceNe Nerd Font 10";
    };

    Interface = {
      activate_item_on_single_click = 1;
      buttonbox_layout = 0;
      cursor_flash_time = 1000;
      dialog_buttons_have_icons = 1;
      double_click_interval = 400;
      gui_effects =
        null; # You might need to adjust this depending on Nix version
      keyboard_scheme = 2;
      menus_have_icons = true;
      show_shortcuts_in_context_menus = true;
      stylesheets =
        null; # You might need to adjust this depending on Nix version
      toolbutton_style = "kvantum";
      underline_shortcut = 1;
      wheel_scroll_lines = 3;
    };

    Troubleshooting = {
      force_raster_widgets = 1;
      ignored_applications =
        null; # You might need to adjust this depending on Nix version
    };
  };

  colorSchemePath = "${pkgs.catppuccin}/qt5ct/Catppuccin-Macchiato.conf";
in
{
  options.fmf.desktop.addons.qt = with types; {
    enable = mkBoolOpt false "Whether to customize qt and apply themes.";
    theme = {
      name = mkOpt str "Catppuccin-Macchiato-Blue"
        "The name of the kvantum theme to apply.";
      pkg = mkOpt package pkgs.catppuccin-kvantum
        "The package to use for the theme.";
    };
  };
  config = mkIf cfg.enable {
    xdg.configFile = {
      "Kvantum".source = ./Kvantum;
      "qt5ct/qt5ct.conf".text = lib.generators.toINI { } (settings // {
        Appearance = mergeAttrs settings.Appearance {
          color_scheme_path = colorSchemePath;
        };
      });
      "qt6ct/qt6ct.conf".text = lib.generators.toINI { } (settings // {
        Appearance = mergeAttrs settings.Appearance {
          color_scheme_path = colorSchemePath;
        };
      });
    };

    qt = {
      enable = true;

      platformTheme.name = mkDefault "qtct";
      # Don't set style.name or style.package here to avoid conflicts with Stylix
      # Instead, rely on qt5ct/qt6ct config files above
    };

    # Install the theme package separately
    home.packages = [
      (cfg.theme.pkg.override {
        accent = "blue";
        variant = "macchiato";
      })
    ];
  };
}
