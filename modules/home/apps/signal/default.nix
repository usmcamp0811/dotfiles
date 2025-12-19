{ options
, config
, lib
, pkgs
, ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.apps.signal;
  wrappedSignal = pkgs.writeShellScriptBin "wrapped-signal-desktop" ''
    QT_QPA_PLATFORM=xcb exec ${pkgs.signal-desktop}/bin/signal-desktop "$@"
  '';
in
{
  options.fmf.apps.signal = with types; {
    enable = mkBoolOpt false "Whether or not to enable signal.";
  };

  config = mkIf cfg.enable { home.packages = [ wrappedSignal pkgs.signal-desktop ]; };
}
