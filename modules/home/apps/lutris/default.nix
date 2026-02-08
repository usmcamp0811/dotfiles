{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.apps.lutris;
in {
  options.fmf.apps.lutris = with types; {
    enable = mkBoolOpt false "Whether or not to enable lutris.";
  };

  config = mkIf cfg.enable {home.packages = with pkgs; [lutris];};
}
