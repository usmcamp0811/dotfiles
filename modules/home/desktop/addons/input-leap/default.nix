{ options
, config
, lib
, pkgs
, ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.desktop.addons.input-leap;
in
{
  options.fmf.desktop.addons.input-leap = with types; {
    enable =
      mkBoolOpt false
        "Whether to enable input-leap in the desktop environment.";
  };
  config = mkIf cfg.enable { home.packages = [ pkgs.input-leap ]; };
}
