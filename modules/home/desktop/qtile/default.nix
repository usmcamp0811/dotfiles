{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.fmf; {
  options.fmf.desktop.qtile = with types; {
    enable = mkBoolOpt false "Whether or not to turn on qtile config.";
    wallpaper = mkOpt str "hsv-saturnV.png" "Name of the Wallpaper to Set";
    lat-lon = mkOpt str "34.6503:86.7757" "Lat Long for Redshift.";
    lock-time = mkOpt str "10" "Time in Minutes to wait to lock the screen";
    config =
      mkOpt str "config.py"
      "Config path for qtile. These are local to the module.";
  };

  config = let
    cfg = config.fmf.desktop.qtile;
    QtileAutostart = pkgs.writeShellScript "autostart.sh" ''

      [[ $(xrandr --listactivemonitors | grep 1440) -eq 0 ]] && export GDK_SCALE=1 || export GDK_SCALE=1.33
      ${pkgs.redshift}/bin/redshift-gtk -l ${cfg.lat-lon} -t 5700:3600 -g 0.8 -m randr -v &
      ${pkgs.xautolock}/bin/xautolock -time ${cfg.lock-time} -locker i3lock-fancy &
      ${pkgs.networkmanagerapplet}/bin/nm-applet &
      ${pkgs.feh}/bin/feh --bg-scale $HOME/Pictures/wallpapers/${cfg.wallpaper}
    '';
  in
    mkIf cfg.enable {
      home.file.".config/qtile/config.py".source =
        builtins.path {
          name = "qtile-config";
          path = ./.;
        }
        + "/${cfg.config}";
      home.file.".config/qtile/custom/layout/master_stack.py".source =
        ./master_stack.py;
      home.file.".config/qtile/custom/layout/__init__.py".text = ''
        from .master_stack import MasterStack
      '';
      home.file.".config/qtile/autostart.sh" = {
        source = QtileAutostart;
        executable = true;
      };
    };
}
