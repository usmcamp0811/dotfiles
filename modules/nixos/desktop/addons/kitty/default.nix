{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.desktop.addons.kitty;
in {
  options.fmf.desktop.addons.kitty = with types; {
    enable =
      mkBoolOpt false "Whether to enable Kitty in the desktop environment.";
  };

  config =
    mkIf cfg.enable {environment.systemPackages = with pkgs; [kitty];};
}
