{ options
, config
, lib
, pkgs
, ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.apps.signal;
  wrappedSignal = pkgs.writeShellScriptBin "wrapped-signal-desktop" ''
    QT_QPA_PLATFORM=xcb exec ${pkgs.signal-desktop}/bin/signal-desktop "$@"
  '';
in
{
  options.campground.apps.signal = with types; {
    enable = mkBoolOpt false "Whether or not to enable signal.";
  };

  config = mkIf cfg.enable { home.packages = [ wrappedSignal pkgs.signal-desktop ]; };
}
