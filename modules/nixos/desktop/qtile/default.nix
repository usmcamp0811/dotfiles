{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.desktop.qtile;

  # TODO: Look at renaming.. figure this could be used to put gui apps that make qtile config pretty and what not
  defaultExtensions = with pkgs; [networkmanagerapplet arc-theme];
in {
  options.fmf.desktop.qtile = with types; {
    enable =
      mkBoolOpt false "Whether or not to use Qtile as the desktop environment.";
  };

  config = mkIf cfg.enable {
    fmf.system.xkb.enable = true;
    fmf.desktop.addons = {wallpapers = enabled;};

    environment.systemPackages = with pkgs;
      [
        gtk4
        python312Packages.qtile
        rofi
        xclip
        xsel
        feh
        dunst
        autorandr
        arandr
        go-sct
        brightnessctl
      ]
      ++ defaultExtensions;

    services.udev.packages = with pkgs; [];
    services.picom.enable = true;

    # renamed option
    services.desktopManager.gnome.extraGSettingsOverrides = ''
      [org.gnome.desktop.interface]
      gtk-theme='Arc-Dark'
    '';

    environment.etc = let
      rofiThemes = "${pkgs.rofi}/share/rofi/themes";
    in
      mapAttrs'
      (name: _: {
        name = "rofi/themes/${name}";
        value = {source = "${rofiThemes}/${name}";};
      })
      (builtins.readDir rofiThemes);

    services.libinput.enable = true;
    services.xserver = {
      enable = true;
      windowManager.qtile = {
        enable = true;
        # extraPackages = python3Packages: with python3Packages; [
        #   qtile-extras
        # ];
      };
    };
    fmf.home.extraOptions = {};
  };
}
