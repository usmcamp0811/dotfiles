{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.tools.liquidctl;
in {
  options.fmf.tools.liquidctl = with types; {
    enable = mkBoolOpt false "Whether or not to enable common DVC.";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [liquidctl];
  };
}
