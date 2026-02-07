{
  config,
  lib,
  options,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.desktop.addons.electron-support;
in {
  options.fmf.desktop.addons.electron-support = {
    enable =
      mkBoolOpt false
      "Whether to enable electron support in the desktop environment.";
  };

  config = mkIf cfg.enable {
    environment.sessionVariables = {NIXOS_OZONE_WL = "1";};

    fmf.home.configFile."electron-flags.conf".source =
      ./electron-flags.conf;
  };
}
