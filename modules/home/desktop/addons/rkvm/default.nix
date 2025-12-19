{ options
, config
, lib
, pkgs
, ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.desktop.addons.rkvm;
in
{
  options.fmf.desktop.addons.rkvm = with types; {
    enable =
      mkBoolOpt false "Whether to enable rkvm in the desktop environment.";
  };
  config = mkIf cfg.enable { home.packages = [ pkgs.rkvm ]; };
}
