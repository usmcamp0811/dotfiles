{ inputs, pkgs, options, config, lib, ... }:
with lib;
with lib.fmf;
let cfg = config.fmf.desktop.addons.wlsunset;
in {
  options.fmf.desktop.addons.wlsunset = with types; {
    enable =
      mkBoolOpt false "Whether to enable wlsunset in the desktop environment.";
  };
  config = mkIf cfg.enable { home.packages = with pkgs; [ wlsunset ]; };
}
