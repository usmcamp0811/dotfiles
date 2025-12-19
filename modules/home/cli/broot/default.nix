{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.cli.broot;
in {
  options.fmf.cli.broot = with types; {
    enable = mkBoolOpt false "Whether or not to enable broot.";
  };

  config = mkIf cfg.enable {home.packages = with pkgs; [broot];};
}
