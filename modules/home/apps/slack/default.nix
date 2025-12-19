{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.apps.slack;
in {
  options.fmf.apps.slack = with types; {
    enable = mkBoolOpt false "Whether or not to enable Slack Desktop Client.";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [slack];
  };
}
