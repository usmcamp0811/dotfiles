{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.apps.mattermost-desktop;
in {
  options.fmf.apps.mattermost-desktop = with types; {
    enable =
      mkBoolOpt false "Whether or not to enable Mattermost Desktop Client.";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [mattermost-desktop];
  };
}
