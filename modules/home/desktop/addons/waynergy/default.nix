{ options
, config
, lib
, pkgs
, ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.desktop.addons.waynergy;
in
{
  options.fmf.desktop.addons.waynergy = with types; {
    enable =
      mkBoolOpt false "Whether to enable waynergy in the desktop environment.";
  };
  config = mkIf cfg.enable { home.packages = [ pkgs.waynergy ]; };
}
