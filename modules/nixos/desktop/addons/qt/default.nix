{ options, config, lib, pkgs, ... }:
with lib;
with lib.fmf;
let cfg = config.fmf.desktop.addons.qt;
in {
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
    environment = {
      systemPackages = with pkgs;
        [
          (cfg.theme.pkg.override {
            accent = "blue";
            variant = "macchiato";
          })
        ] ++ lib.optional config.fmf.suites.wlroots.enable
          libsForQt5.qt5.qtwayland;
    };

    qt = {
      enable = true;

      platformTheme.name = "qt5ct";
      style = "kvantum";
      # {
      #   name = ;
      #   package = cfg.theme.pkg.override {
      #     accent = "Blue";
      #     variant = "Macchiato";
      #   };
    };
  };
}
