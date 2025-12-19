{
  config,
  lib,
  options,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.desktop.addons.swappy;
in {
  options.fmf.desktop.addons.swappy = {
    enable =
      mkBoolOpt false "Whether to enable Swappy in the desktop environment.";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [swappy];

    fmf.home = {
      configFile."swappy/config".source = ./config;
      file."Pictures/screenshots/.keep".text = "";
    };
  };
}
