{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.tools.protonup-qt;
in {
  options.fmf.tools.protonup-qt = with types; {
    enable = mkBoolOpt false "Whether or not to enable protonup-qt.";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [protonup-qt];
  };
}
