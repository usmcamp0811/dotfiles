{ options
, config
, lib
, pkgs
, ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.desktop.addons.networkmanagerapplet;
in
{
  options.fmf.desktop.addons.networkmanagerapplet = with types; {
    enable =
      mkBoolOpt false
        "Whether to enable networkmanagerapplet in the desktop environment.";
  };
  config = mkIf cfg.enable { home.packages = [ pkgs.networkmanagerapplet ]; };
}
